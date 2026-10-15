import {problem} from './security.mjs';
// Container and dimension checks, not malware scanning or full image re-encoding.
export function validatedPhoto(value, maximum=700000){
 if(value==null)return null;
 if(typeof value!=='string'||value.length>maximum)problem('INVALID_PHOTO');
 const match=/^data:image\/(png|jpeg|webp);base64,([A-Za-z0-9+/]+={0,2})$/.exec(value);
 if(!match||match[2].length%4!==0)problem('INVALID_PHOTO');
 let bytes;try{bytes=Uint8Array.from(atob(match[2]),x=>x.charCodeAt(0));}catch{problem('INVALID_PHOTO');}
 const view=new DataView(bytes.buffer),ascii=(p,n)=>String.fromCharCode(...bytes.slice(p,p+n));let width=0,height=0;
 if(match[1]==='png'){
  if(bytes.length<45||ascii(1,3)!=='PNG'||bytes[0]!==137||view.getUint32(4)!==0x0d0a1a0a||view.getUint32(8)!==13||ascii(12,4)!=='IHDR')problem('INVALID_PHOTO');
  width=view.getUint32(16);height=view.getUint32(20);let ended=false,hasData=false;
  for(let p=8;p+12<=bytes.length;){const n=view.getUint32(p),kind=ascii(p+4,4);if(n>bytes.length-p-12||kind==='acTL')problem('INVALID_PHOTO');if(kind==='IDAT')hasData=true;p+=12+n;if(kind==='IEND'){ended=n===0&&p===bytes.length;break;}}
  if(!ended||!hasData)problem('INVALID_PHOTO');
 }else if(match[1]==='jpeg'){
  if(bytes.length<12||view.getUint16(0)!==0xffd8||view.getUint16(bytes.length-2)!==0xffd9)problem('INVALID_PHOTO');
  let p=2;while(p+4<bytes.length){if(bytes[p++]!==255)problem('INVALID_PHOTO');while(bytes[p]===255)p++;const marker=bytes[p++];if(marker===0xda)break;if(marker===0x01||(marker>=0xd0&&marker<=0xd7))continue;const n=view.getUint16(p);if(n<2||p+n>bytes.length)problem('INVALID_PHOTO');if([0xc0,0xc1,0xc2,0xc3,0xc5,0xc6,0xc7,0xc9,0xca,0xcb,0xcd,0xce,0xcf].includes(marker)){if(n<8)problem('INVALID_PHOTO');height=view.getUint16(p+3);width=view.getUint16(p+5);}p+=n;}
 }else{
  if(bytes.length<30||ascii(0,4)!=='RIFF'||ascii(8,4)!=='WEBP'||view.getUint32(4,true)+8!==bytes.length)problem('INVALID_PHOTO');
  const u24=p=>bytes[p]|bytes[p+1]<<8|bytes[p+2]<<16,kind=ascii(12,4);
  if(kind==='VP8X'){if(bytes[20]&2)problem('INVALID_PHOTO');width=1+u24(24);height=1+u24(27);}
  else if(kind==='VP8 '&&ascii(23,3)==='\x9d\x01\x2a'){width=view.getUint16(26,true)&0x3fff;height=view.getUint16(28,true)&0x3fff;}
  else if(kind==='VP8L'&&bytes[20]===0x2f){const bits=view.getUint32(21,true);width=(bits&0x3fff)+1;height=((bits>>>14)&0x3fff)+1;}
  else problem('INVALID_PHOTO');
  let hasImage=false;for(let p=12;p+8<=bytes.length;){const n=view.getUint32(p+4,true),type=ascii(p,4);if(n>bytes.length-p-8||type==='ANIM'||type==='ANMF')problem('INVALID_PHOTO');if(type==='VP8 '||type==='VP8L')hasImage=true;p+=8+n+(n%2);if(p>bytes.length)problem('INVALID_PHOTO');}if(!hasImage)problem('INVALID_PHOTO');
 }
 if(width<1||height<1||width>4096||height>4096||width*height>16000000)problem('INVALID_PHOTO');return value;
}
