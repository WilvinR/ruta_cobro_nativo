/* Conexión con Firebase. La configuración (prueba o producción) está en config.js */
import{firebaseConfig}from"./config.js";
import{initializeApp}from"https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js";
import{getAuth,GoogleAuthProvider,signInWithPopup,signInWithRedirect,getRedirectResult,signOut,onAuthStateChanged}from"https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js";
import{getFirestore,collection,addDoc,query,where,getDocs,doc,getDoc,setDoc,updateDoc,writeBatch,serverTimestamp}from"https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js";
const app=initializeApp(firebaseConfig);
const auth=getAuth(app),fs=getFirestore(app);let me=null;
/* Copia local de lo último conocido en el servidor (para guardar sin releer todo) */
let _serverSnap={clientes:new Map(),prestamos:new Map(),pagos:new Map()};
function _takeSnap(C,L,P){
 return{
  clientes:new Map((C||[]).filter(x=>x&&x.id).map(x=>[x.id,JSON.parse(JSON.stringify(x))])),
  prestamos:new Map((L||[]).filter(x=>x&&x.id).map(x=>[x.id,JSON.parse(JSON.stringify(x))])),
  pagos:new Map((P||[]).filter(x=>x&&x.id).map(x=>[x.id,JSON.parse(JSON.stringify(x))]))
 };
}
/* Contadores de uso (solo números): clientes, préstamos activos, nuevos por día y último movimiento */
const doneL=l=>l.type==="c"?(l.total-l.paid<=0.005):(l.principal<=0.005);
const dkey=t=>{const d=new Date(t);return d.getFullYear()+"-"+String(d.getMonth()+1).padStart(2,"0")+"-"+String(d.getDate()).padStart(2,"0")};
function prune(d){const o={},lim=dkey(Date.now()-31*864e5);Object.keys(d||{}).forEach(k=>{if(k>=lim&&Array.isArray(d[k]))o[k]=d[k]});return o}
async function pushStats(st){try{await updateDoc(doc(fs,"users",auth.currentUser.uid),{stats:st});if(me)me.stats=st}catch(e){}}
function syncStats(C,L,P){try{const act=L.filter(l=>l&&!doneL(l)).length,s=me&&me.stats;
 if(s&&s.c===C.length&&s.l===act)return;
 let m=(s&&s.m)||0;
 if(!s){const now=Date.now();[...P.map(p=>p&&p.date),...L.map(l=>l&&l.startDate)].forEach(x=>{const t=x?new Date(x+"T12:00:00").getTime():0;if(t&&t<=now&&t>m)m=t})}
 pushStats({c:C.length,l:act,m,d:prune(s&&s.d)})}catch(e){}}
function initials(n){const w=String(n||"").normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^A-Za-z ]/g," ").trim().split(/\s+/).filter(Boolean);
 if(!w.length)return"XX";return(w.length>1?w[0][0]+w[1][0]:w[0].slice(0,2)).toUpperCase().padEnd(2,"X")}
async function newCode(name){const i=initials(name);
 for(let k=0;k<15;k++){const c="RC-"+i+(1000+Math.floor(Math.random()*9000)),r=doc(fs,"codes",c);
  if(!(await getDoc(r)).exists()){await setDoc(r,{t:1});return c}}
 throw new Error("code")}
window.FB={
 get me(){return me},
 onUser:cb=>onAuthStateChanged(auth,cb),
 signIn:()=>{const p=new GoogleAuthProvider();p.setCustomParameters({prompt:"select_account"});return signInWithPopup(auth,p).catch(e=>{if(e.code==="auth/popup-blocked")return signInWithRedirect(auth,p);throw e})},
 redirectResult:()=>getRedirectResult(auth),
 signOut:()=>{me=null;return signOut(auth)},
 refresh:async()=>{if(auth.currentUser)await window.FB.ready(auth.currentUser)},
 getConfig:async()=>{const s=await getDoc(doc(fs,"config","app"));return s.exists()?s.data():{}}, dismissAnnouncement:async id=>{if(!id||!auth.currentUser)return;await setDoc(doc(fs,"users",auth.currentUser.uid),{announcementSeen:id},{merge:true});if(me)me.announcementSeen=id},
 get user(){return auth.currentUser},
 setPending:(plan,amount)=>{me.pending=true;return setDoc(doc(fs,"pendientes",auth.currentUser.uid),{uid:auth.currentUser.uid,code:me.code,name:me.name,plan,amount,sentAt:serverTimestamp()})},
 sendMessage:text=>addDoc(collection(fs,"mensajes"),{uid:auth.currentUser.uid,code:me.code,name:me.name,email:me.email,text,createdAt:serverTimestamp(),status:"nuevo"}),
 myMessages:async()=>{const r=await getDocs(query(collection(fs,"mensajes"),where("uid","==",auth.currentUser.uid)));
  return r.docs.map(d=>{const x=d.data();return{id:d.id,text:x.text,status:x.status,reply:x.reply||"",t:x.createdAt&&x.createdAt.toMillis?x.createdAt.toMillis():Date.now()}}).sort((a,b)=>b.t-a.t)},
 ready:async u=>{const ref=doc(fs,"users",u.uid);let s=await getDoc(ref);
  if(!s.exists()){const nm=u.displayName||(u.email||"").split("@")[0],c=await newCode(nm);
   await setDoc(ref,{name:nm,email:u.email||"",code:c,createdAt:serverTimestamp()});s=await getDoc(ref)}
  const d=s.data();["createdAt","paidUntil","exemptUntil"].forEach(k=>{if(d[k]&&d[k].toMillis)d[k]=d[k].toMillis()});try{d.pending=(await getDoc(doc(fs,"pendientes",u.uid))).exists()}catch(e){d.pending=false}me=d},
 /* true = ya se bajó el historial completo de pagos; false = solo pagos de hoy (u otros parciales) */
 _pagosFull:false,
 loadData:async()=>{
  const uid=auth.currentUser.uid;
  /* Al abrir: clientes + préstamos + SOLO pagos de hoy (no todo el historial) */
  const t=(()=>{const d=new Date();return d.getFullYear()+"-"+String(d.getMonth()+1).padStart(2,"0")+"-"+String(d.getDate()).padStart(2,"0")})();
  const [cs,ls,psHoy]=await Promise.all([
   getDocs(collection(fs,"datos",uid,"clientes")),
   getDocs(collection(fs,"datos",uid,"prestamos")),
   getDocs(query(collection(fs,"datos",uid,"pagos"),where("date","==",t)))
  ]);
  if(!cs.empty||!ls.empty||!psHoy.empty){
   const C=cs.docs.map(d=>d.data()),L=ls.docs.map(d=>d.data()),P=psHoy.docs.map(d=>d.data());
   window.FB._pagosFull=false;
   _serverSnap=_takeSnap(C,L,P);
   syncStats(C,L,P);
   return JSON.stringify({clients:C,loans:L,payments:P,settings:{}})
  }
  window.FB._pagosFull=true;
  _serverSnap=_takeSnap([],[],[]);
  return null;
 },
 /* Baja TODOS los pagos (Historial / Resumen / Excel). Solo se llama cuando hace falta. */
 loadAllPayments:async()=>{
  if(window.FB._pagosFull)return;
  const uid=auth.currentUser.uid;
  const r=await getDocs(collection(fs,"datos",uid,"pagos"));
  const P=r.docs.map(d=>d.data());
  window.FB._pagosFull=true;
  /* Fusionar en el snap de pagos sin tocar clientes/préstamos */
  const prev=_serverSnap.pagos||new Map();
  P.forEach(x=>{if(x&&x.id)prev.set(x.id,JSON.parse(JSON.stringify(x)))});
  _serverSnap.pagos=prev;
  return P;
 },
 /* Baja pagos de un cliente (ficha del cliente). */
 loadClientPayments:async clientId=>{
  if(window.FB._pagosFull)return null;
  const uid=auth.currentUser.uid;
  const r=await getDocs(query(collection(fs,"datos",uid,"pagos"),where("clientId","==",clientId)));
  const P=r.docs.map(d=>d.data());
  const prev=_serverSnap.pagos||new Map();
  P.forEach(x=>{if(x&&x.id)prev.set(x.id,JSON.parse(JSON.stringify(x)))});
  _serverSnap.pagos=prev;
  return P;
 },
 /* Borrar en servidor todos los pagos de un cliente o préstamo (aunque no estén en memoria). */
 deletePaymentsQuery:async(field,value)=>{
  const uid=auth.currentUser.uid;
  const r=await getDocs(query(collection(fs,"datos",uid,"pagos"),where(field,"==",value)));
  const ids=r.docs.map(d=>d.id);
  for(let i=0;i<ids.length;i+=450){
   const b=writeBatch(fs);
   ids.slice(i,i+450).forEach(id=>b.delete(doc(fs,"datos",uid,"pagos",id)));
   await b.commit();
  }
  ids.forEach(id=>{if(_serverSnap.pagos)_serverSnap.pagos.delete(id)});
  return ids.length;
 },
 /* Guardado optimizado: NO lee de nuevo. Compara con la copia local (_serverSnap) y solo escribe lo que cambió.
    Si los pagos no están completos en memoria, NO borra del servidor pagos que no están cargados. */
 saveData:async j=>{
  const uid=auth.currentUser.uid,d=JSON.parse(j),groups={clientes:d.clients||[],prestamos:d.loans||[],pagos:d.payments||[]};
  const ops=[];
  const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
  const prevSnap=_serverSnap;
  const pagosFull=!!window.FB._pagosFull;
  for(const [col,arr] of Object.entries(groups)){
   const next=new Map((arr||[]).filter(x=>x&&x.id).map(x=>[x.id,x]));
   const prev=prevSnap[col]||new Map();
   for(const [id,x] of next){if(!prev.has(id)||!same(prev.get(id),x))ops.push({t:"set",ref:doc(fs,"datos",uid,col,id),data:x});}
   /* Borrar solo lo que conocíamos en memoria y ya no está.
      En pagos parciales solo se borran los que sí estaban en el snap (nunca el historial no cargado). */
   for(const id of prev.keys())if(!next.has(id))ops.push({t:"del",ref:doc(fs,"datos",uid,col,id)});
  }
  ops.push({t:"set",ref:doc(fs,"datos",uid,"meta","main"),data:{version:2,updatedAt:serverTimestamp(),saveMode:"delta",pagosFull},merge:true});
  for(let i=0;i<ops.length;i+=450){const b=writeBatch(fs);for(const o of ops.slice(i,i+450))o.t==="del"?b.delete(o.ref):b.set(o.ref,o.data,o.merge?{merge:true}:undefined);await b.commit()}
  /* Actualizar snap: clientes/préstamos completos; pagos = fusionar lo que hay en memoria */
  _serverSnap.clientes=_takeSnap(d.clients,[],[]).clientes;
  _serverSnap.prestamos=_takeSnap([],d.loans,[]).prestamos;
  const paySnap=_serverSnap.pagos||new Map();
  (d.payments||[]).filter(x=>x&&x.id).forEach(x=>paySnap.set(x.id,JSON.parse(JSON.stringify(x))));
  /* Quitar del snap pagos que se borraron de memoria y estaban en prev */
  const nextPay=new Set((d.payments||[]).filter(x=>x&&x.id).map(x=>x.id));
  for(const id of [...paySnap.keys()]){
   if(!nextPay.has(id)&&(prevSnap.pagos||new Map()).has(id))paySnap.delete(id);
  }
  _serverSnap.pagos=paySnap;
  try{
   const cnt=col=>{
    const prev=prevSnap[col]||new Map();
    return [...new Set((groups[col]||[]).filter(x=>x&&x.id).map(x=>x.id))].filter(id=>!prev.has(id)).length;
   };
   const nC=cnt("clientes"),nL=cnt("prestamos"),nP=cnt("pagos"),cT=new Set((d.clients||[]).filter(x=>x&&x.id).map(x=>x.id)).size,act=(d.loans||[]).filter(l=>l&&l.id&&!doneL(l)).length;
   const s=(me&&me.stats)||{},dd=prune(s.d),k=dkey(Date.now()),mv=(nC||nL||nP)?Date.now():(s.m||0);
   if(nC||nL||nP){const x=dd[k]||[0,0,0];dd[k]=[x[0]+nC,x[1]+nL,x[2]+nP]}
   if(s.c!==cT||s.l!==act||nC||nL||nP)await pushStats({c:cT,l:act,m:mv,d:dd});
  }catch(e){}
 }
};
window.dispatchEvent(new Event("fb-ready"));
