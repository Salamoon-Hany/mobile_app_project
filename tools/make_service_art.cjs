const fs=require('node:fs');
const path=require('node:path');
let sharp;
try { sharp = require('sharp'); } catch (_) {
  sharp = require(require.resolve('sharp', {paths:[process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES].filter(Boolean)}));
}
const drawings={
 builder:'<path d="M42 122V54h74v68M57 70h14m17 0h14M57 89h14m17 0h14M43 108h26m26 0h22M72 122v-19h16v19"/>',
 electrician:'<path d="M63 47v22m34-22v22M56 70h48v16c0 18-10 27-24 27v18m-12-47h24"/><path fill="#D7FF00" stroke="none" d="m84 92-15 19h11l-2 12 16-21H83Z"/>',
 plumber:'<path d="M34 78h29V54h31v24h31m-19-14v28M52 64v28M79 79v34m-14-12h28"/><path d="M111 111c-9 12-12 16-12 21a12 12 0 0 0 24 0c0-5-3-9-12-21Z" fill="#D7FF00"/>',
 carpenter:'<path d="m39 111 63-63 18 18-58 61-8-8-8 2-7-10Z" fill="#D7FF00"/><path d="m101 49 16-15 21 21-16 16m-81 52h71M62 95l5 5m5-15 5 5m5-15 5 5"/>',
 tiler:'<rect x="38" y="38" width="84" height="84" rx="9"/><path d="M80 39v82M39 80h82"/><rect x="91" y="91" width="16" height="16" rx="2" fill="#D7FF00" stroke="none"/>',
 steel_fixer:'<path d="m42 50 68 68m-57-76 68 68M42 111l69-69m-58 80 69-69"/><path d="M28 134h105"/>',
 plasterer:'<path d="m42 107 69-8-22-60-47 68Z" fill="#D7FF00"/><path d="m81 83 17 14 15-11m-16 14 17 18 19-17-17-18"/>',
 repairing:'<path d="M52 34a27 27 0 0 0 29 37l47 47-15 15-47-47a27 27 0 0 1-33-34l17 17 17-17-15-18Z" fill="#D7FF00"/>',
 gardener:'<path d="M80 130V85m0 20C42 104 35 71 40 58c32 2 45 17 40 47Zm0-19c38 0 46-30 41-47-31 2-46 18-41 47Z" fill="#D7FF00"/><path d="M60 131h41"/>',
 heavy_equipment:'<rect x="32" y="101" width="80" height="25" rx="12"/><path d="M43 109h59M51 101V68h39v33m-26-34V53h31l22 27 18-7M135 71v43l-21 3m-20-64 12-20 23 17-12 25"/>',
 rubbish:'<path d="M45 56h70m-58 0 6 71h35l6-71M68 41h24l5 14M75 73v38m17-38v38"/><path d="m40 38 10-9m65 9 10-9" stroke="#A6BD39"/>',
 cleaning:'<path d="m92 34-24 53m-5-2 30 13-21 36-37-17 28-32Z" fill="#D7FF00"/><path d="m53 111 21 9M121 48v29m-15-15h30M121 108v16m-8-8h16"/>',
 air_conditioning:'<rect x="28" y="44" width="106" height="48" rx="11"/><path d="M41 77h80M110 57h10M54 102v24m27-24v31m26-31v24"/><path d="m49 119 5 7 5-7m17 8 5 7 5-7m16-8 5 7 5-7"/>',
 painting:'<rect x="35" y="39" width="85" height="31" rx="8" fill="#D7FF00"/><path d="M121 54h12v35H82v35m-8-2h16v19H74Z"/>',
};
(async()=>{
 for(const [id,drawing] of Object.entries(drawings)){
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 160"><rect width="160" height="160" rx="32" fill="#F1F5E4"/><circle cx="113" cy="45" r="30" fill="#D7FF00" opacity=".65"/><g fill="none" stroke="#171917" stroke-width="6" stroke-linecap="round" stroke-linejoin="round">${drawing}</g></svg>`;
  fs.writeFileSync(path.join('Pics & Icons',`service-${id}.svg`),svg);
  await sharp(Buffer.from(svg)).resize(320,320).png().toFile(path.join('Pics & Icons',`service-${id}.png`));
 }
 console.log(`Prepared ${Object.keys(drawings).length} consistent service illustrations.`);
})();
