// The app bundle embeds these bytes; the web export points to immutable files.
export async function readAsset(id,received){
  const tag=document.getElementById(id);
  if(!tag.dataset.src){
    const raw=atob(tag.textContent.trim()),bytes=new Uint8Array(raw.length);
    for(let i=0;i<raw.length;i++)bytes[i]=raw.charCodeAt(i);
    return bytes.buffer;
  }
  const response=await fetch(tag.dataset.src);
  if(!response.ok)throw Error(id+" "+response.status);
  if(!response.body||!received)return response.arrayBuffer();
  const reader=response.body.getReader(),chunks=[];
  let count=0;
  try{
    while(true){
      const {value,done}=await reader.read();
      if(done)break;
      chunks.push(value);count+=value.length;received(id,count);
    }
  }finally{reader.releaseLock()}
  const result=new Uint8Array(count);let offset=0;
  for(const chunk of chunks){result.set(chunk,offset);offset+=chunk.length}
  return result.buffer;
}
export function imageAsset(id,mime){
  const tag=document.getElementById(id);
  return tag.dataset.src||"data:"+mime+";base64,"+tag.textContent.trim();
}
