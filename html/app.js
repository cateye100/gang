
// === CT-GANG: robust world->pixel projector with configurable bounds ===
(function(){
  if (!window.CTMapProject) window.CTMapProject = {};
  window.__ctGangColors = window.__ctGangColors || {};
  // Configure default world bounds for gta5_map_full.png (adjust in config if needed)
  if (!window.CTMapProject.bounds){
    window.CTMapProject.bounds = {
      // Default guess for GTA V world extents; tweak if needed
      minX: -4200, maxX: 4500,
      minY: -4200, maxY: 8000
    };
  }
  function worldToPixelDefault(x, y){
    try{
      const img = document.getElementById('mapLayer');
      const W = (img && img.naturalWidth)  || 4096;
      const H = (img && img.naturalHeight) || 4096;
      const b = window.CTMapProject.bounds;
      const u = (x - b.minX) / (b.maxX - b.minX);
      const v = 1 - (y - b.minY) / (b.maxY - b.minY); // invert Y for image coords
      return { x: u * W, y: v * H };
    }catch(e){ return null; }
  }
  // pick a projector
  if (!window.worldToPixel){
    const cands = [window._worldToPixel, window.worldToImage, window.mapProject, window.toPixel];
    let chosen = null;
    for (const fn of cands){ if (typeof fn === 'function'){ chosen = fn; break; } }
    window.worldToPixel = chosen || worldToPixelDefault;
  }
})();


// === UI bootstrap: request cached areas immediately, then server refresh ===
(function(){
  try{
    fetch('https://ct-gang/uiReady', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({}) })
      .then(function(r){ return r.text(); })
      .then(function(t){ var j={}; try{ j = t ? JSON.parse(t) : {}; }catch(e){}; (window.setAreas||function(){})(j.areas||[]); })
      .catch(function(){});
  }catch(e){}
})();


// === Territories renderer
  function gangColor(ownerKey, alpha){
    try{
      var k = String(ownerKey||'').toLowerCase().replace(/\s+/g,'_');
      var c = (window.__ctGangColors||{})[k];
      if(!c){ return 'rgba(255,255,255,'+(alpha==null?0.12:alpha)+')'; }
      var a = (alpha==null?0.28:alpha);
      return 'rgba(' + (c.r||255) + ',' + (c.g||255) + ',' + (c.b||255) + ',' + a + ')';
    }catch(e){ return 'rgba(255,255,255,'+(alpha==null?0.12:alpha)+')'; }
  }
(function(){


  
function applyColorWithAlpha(el, prop, value, fallback){
  try{
    var v = value || fallback || '';
    if(!v){ return; }
    var m = String(v).match(/rgba?\((\s*\d+\s*),(\s*\d+\s*),(\s*\d+\s*)(?:,(\s*[0-1]?(?:\.\d+)?))?\)/i);
    if(m){
      var r = parseInt(m[1]), g = parseInt(m[2]), b = parseInt(m[3]);
      var a = m[4] != null ? parseFloat(m[4]) : 1;
      if(prop === 'fill'){
        el.setAttribute('fill', 'rgb(' + r + ',' + g + ',' + b + ')');
        el.setAttribute('fill-opacity', String(a));
      }else if(prop === 'stroke'){
        el.setAttribute('stroke', 'rgb(' + r + ',' + g + ',' + b + ')');
        el.setAttribute('stroke-opacity', String(a));
      }
      return;
    }
    // fallback plain color
    el.setAttribute(prop, v);
  }catch(e){
    el.setAttribute(prop, fallback || '#00c8ff');
  }
}

  function ensureSVG(){
    if (!window.__ct_svgEl){
      var overlay = document.getElementById('mapOverlay');
      var img = document.getElementById('mapLayer');
      if (!overlay || !img) return null;
      // Size overlay to image's intrinsic dimensions so 1px in SVG = 1px on the image before transforms
      var iw = img.naturalWidth || img.width || 1365;
      var ih = img.naturalHeight || img.height || 2048;
      overlay.style.position = 'absolute';
      overlay.style.left = '0'; overlay.style.top = '0';
      overlay.style.width = iw + 'px';
      overlay.style.height = ih + 'px';
      overlay.style.zIndex = '11';  // ensure above the image

      var s = document.createElementNS('http://www.w3.org/2000/svg','svg');
      s.setAttribute('id','polySvg');
      s.setAttribute('viewBox', '0 0 ' + iw + ' ' + ih);
      s.setAttribute('width', String(iw));
      s.setAttribute('height', String(ih));
      s.style.position='absolute'; s.style.left='0'; s.style.top='0';
      s.style.pointerEvents='none'; s.style.zIndex='12';
      overlay.appendChild(s);
      window.__ct_svgEl = s;
    }
    return window.__ct_svgEl;
  }
function tryWorldToPixel(x, y){
    var cands = [window.worldToPixel, window._worldToPixel, window.worldToImage, window.mapProject, window.toPixel];
    for (var i=0;i<cands.length;i++){
      var fn = cands[i];
      if (typeof fn === 'function'){
        try { var m = fn(x, y); if (m) return m; } catch(e){}
      }
    }
    return null;
  }

  function drawOneArea(ar){
    var s = ensureSVG(); if (!s) return;
    var px = ar.polygon_pixels;

    if ((!px || !px.length) && ar.polygon_world && ar.polygon_world.length){
      var tmp = [];
      for (var i=0;i<ar.polygon_world.length;i++){
        var p = ar.polygon_world[i];
        var x = (p.x != null ? p.x : p[0]);
        var y = (p.y != null ? p.y : p[1]);
        var m = tryWorldToPixel(x, y);
        if (!m){ console.warn('Missing world->pixel projector'); return; }
        tmp.push({ x: (m.x!=null?m.x:m[0]), y: (m.y!=null?m.y:m[1]) });
      }
      px = tmp; try{ if(px && px.length){ console.log('DEBUG px[0..1]', JSON.stringify(px[0]), JSON.stringify(px[1])); } }catch(e){}
    }
    if (!px || !px.length) return;

    var pts = px.map(function(p){ return (p.x!=null?p.x:p[0]) + ',' + (p.y!=null?p.y:p[1]); }).join(' ');
    var pl = document.createElementNS('http://www.w3.org/2000/svg','polygon');
    pl.setAttribute('points', pts);
    applyColorWithAlpha(pl, 'fill', ar.fill, 'rgba(255,255,255,0.10)');
    applyColorWithAlpha(pl, 'stroke', ar.stroke, 'rgba(255,255,255,0.85)');
    pl.setAttribute('stroke-width', String(ar.stroke_width || 2));
    pl.style.pointerEvents='none';
    (window.__ct_svgEl || s).appendChild(pl);
// label suppressed as requested







  }

  function clearAreas(){ var s=window.__ct_svgEl; if(!s) return; while(s.firstChild) s.removeChild(s.firstChild); }
  window.setAreas = function(list){ window.__areasLatest = list || []; try{ toast('Territories: ' + window.__areasLatest.length); }catch(e){}; var sEl = ensureSVG(); if (!sEl){ return; } clearAreas(); (list||[]).forEach(drawOneArea); }
  window.addArea = function(ar){ ensureSVG(); drawOneArea(ar); }

  // Live push from client.lua
  window.addEventListener('message', function(ev){
    var d = ev.data || {};
    if (d.action === 'ctgang:setGangColors') { window.__ctGangColors = d.colors || {}; }
    else if (d.action === 'ctgang:setAreas') window.setAreas(d.areas || []);
    if (d.action === 'ctgang:addArea') window.addArea(d.area);
    
  });
})();

// === NUI Gang Menu (rensad från demo/pick hotkeys) ===

function $(sel){ return document.querySelector(sel); }
function $all(sel){ return Array.prototype.slice.call(document.querySelectorAll(sel)); }

var panel = $('#panel');
var views = {
  overview: $('#view-overview'),
  members: $('#view-members'),
  ranks: $('#view-ranks'),
  territories: $('#view-territories'),
  bank: $('#view-bank'),
  armory: $('#view-armory'),
  settings: $('#view-settings'),
  audit: $('#view-audit')
};
var toolbars = {
  overview: $('#toolbar-overview'),
  members: $('#toolbar-members'),
  ranks: $('#toolbar-ranks'),
  territories: $('#toolbar-territories'),
  bank: $('#toolbar-bank'),
  armory: $('#toolbar-armory'),
  settings: $('#toolbar-settings'),
  audit: $('#toolbar-audit')
};



function gangDisplayName(){
  function prettyName(x){
    var raw = String(x).replace(/[_-]+/g, ' ').trim();
    return raw.split(' ').map(function(w){ return w ? (w[0].toUpperCase() + w.slice(1)) : w; }).join(' ');
  }
  var g = (state && state.gang) ? state.gang : null;
  if (!g && state && state.PlayerData && state.PlayerData.gang) g = state.PlayerData.gang;
  if (!g && state && state.player && state.player.gang) g = state.player.gang;

  var flatName = null;
  if (state){
    flatName = state.gangLabel || state.ganglabel || state.gangName || state.gangname || state.glabel || state.gname || null;
  }

  var lbl = (g && g.label && String(g.label).trim()) ? g.label : null;
  var nm  = (g && g.name  && String(g.name).trim())  ? g.name  : null;

  if (lbl) return lbl;
  if (nm) return prettyName(nm);
  if (flatName) return prettyName(flatName);
  return 'Gäng';
}

var state = {
  gang: { name:'', label:'', grade:0 },
  members: [],
  ranks: [],
  bank: { balance: 0 },
  audit: [],
  markers: []
};

function toast(msg){
  try{
    var wrap = $('#toasts'); if(!wrap) return;
    var t = document.createElement('div');
    t.className = 'toast';
    t.textContent = String(msg || '');
    t.style.opacity = '0';
    wrap.appendChild(t);
    requestAnimationFrame(function(){ t.style.opacity='1'; });
    setTimeout(function(){ t.style.opacity='0'; setTimeout(function(){ if (t && t.parentNode) t.parentNode.removeChild(t); }, 250); }, 2300);
  }catch(e){}
}

function showPanel(){ if (panel) panel.classList.remove('hidden'); }
function hidePanel(){ if (panel) panel.classList.add('hidden'); }

var currentTab = 'overview';
function setTab(tab){
  currentTab = tab;
  $all('.tabbtn').forEach(function(b){
    var t = b.getAttribute('data-tab');
    if (t === tab) b.classList.add('active'); else b.classList.remove('active');
  });
  for (var k in views){
    if (views.hasOwnProperty(k) && views[k]) views[k].classList.toggle('hidden', k !== tab);
  }
  for (var k2 in toolbars){
    if (toolbars.hasOwnProperty(k2) && toolbars[k2]) toolbars[k2].classList.toggle('hidden', k2 !== tab);
  }
  render();

// Hook close button (✖)
var _cb = document.getElementById('closeBtn');
if (_cb) _cb.addEventListener('click', function(e){ e.preventDefault(); nuiClose(); });
}

// ---- Renderers ----
function render(){
  var gl = $('#gangLabel'); if (gl) gl.textContent = gangDisplayName();
  try { document.title = gangDisplayName(); } catch(e){}
  var oc = $('#onlineCount'); if (oc) oc.textContent = (state.members.filter ? state.members.filter(m => m.online).length : 0);
  if (currentTab === 'overview') renderOverview();
  else if (currentTab === 'members') renderMembers();
  else if (currentTab === 'ranks') renderRanks();
  else if (currentTab === 'bank') renderBank();
  else if (currentTab === 'armory') renderArmory();
  else if (currentTab === 'territories') renderTerritories();
  else if (currentTab === 'settings') renderSettings();
  else if (currentTab === 'audit') renderAudit();
}


function renderOverview(){
  var root = views.overview; if (!root) return;
  var online = (state.members && state.members.filter ? state.members.filter(function(m){return m.online;}).length : 0);
  var total = (state.members ? state.members.length : 0);
  var bank  = (state.bank && state.bank.balance ? state.bank.balance : 0);
  var rank  = (state.gang && state.gang.grade != null ? state.gang.grade : 0);
  root.innerHTML = ''
    + '<div class="grid cols-3">'
    + '  <div class="card"><h3>Namn</h3><div class="stat">' + gangDisplayName() + '</div></div>'
    + '  <div class="card"><h3>Medlemmar online</h3><div class="stat">' + online + ' / ' + total + '</div></div>'
    + '  <div class="card"><h3>Kassa</h3><div class="stat">$' + bank + '</div></div>'
    + '</div>'
    + '<div class="card" style="margin-top:12px"><h3>Snabbinfo</h3>'
    + '  <div class="pill">Rank: ' + rank + '</div>'
    + '</div>';
}

function renderMembers(){ var root=views.members; if (!root) return; root.innerHTML = '<div class="card"><h3>Medlemmar</h3><div class="empty">Demo</div></div>'; }
function renderRanks(){ var root=views.ranks; if (!root) return; root.innerHTML = '<div class="card"><h3>Ranker</h3><div class="empty">Demo</div></div>'; }
function renderBank(){ var root=views.bank; if (!root) return; root.innerHTML = '<div class="card"><h3>Bank</h3><div class="empty">Demo</div></div>'; }
function renderArmory(){ var root=views.armory; if (!root) return; root.innerHTML = '<div class="card"><h3>Vapenförråd</h3><div class="empty">Demo</div></div>'; }
function renderSettings(){ var root=views.settings; if (!root) return; root.innerHTML = '<div class="card"><h3>Inställningar</h3><div class="empty">Demo</div></div>'; }
function renderAudit(){ var root=views.audit; if (!root) return; root.innerHTML = '<div class="card"><h3>Logg</h3><div class="empty">Demo</div></div>'; }

// ---- Territories (utan pick-mode UI) ----
var __territoriesReady = false;
function renderTerritories(){
  var root = views.territories; if (!root) return;
  showPanel();
  if (!__territoriesReady){
    root.innerHTML = '<div class="card"><h3>Territorier</h3><button id="loadMapBtn" class="btn">Ladda karta</button></div>';
    var btn = $('#loadMapBtn');
    if (btn){
      btn.addEventListener('click', function(ev){
        ev.preventDefault(); ev.stopPropagation();
        showPanel();
        if (!__territoriesReady){ resetMap(); __territoriesReady = true; }
      });
    }
  }
}

// ---- Map / NUI ----
var _mapState = { tx:0, ty:0, scale:1.6, min:0.6, max:6 };

// ---- Affine (match client.lua) ----
var Affine = {
  a11: 0.151798598000, a12: 0.00000349709,
  a21: -0.000609547131, a22: -0.151636800,
  t1: 627.884751, t2: 1275.04431
};

function pixelToWorld(u, v){
  var du = u - Affine.t1;
  var dv = v - Affine.t2;
  var det = Affine.a11*Affine.a22 - Affine.a12*Affine.a21;
  if (det === 0) return { x: 0, y: 0 };
  var x = ( du*Affine.a22 - Affine.a12*dv) / det;
  var y = ( Affine.a11*dv - du*Affine.a21) / det;
  return { x: x, y: y };
}

// pick mode: permanent av
var __pickMode = false;
function setPickMode(on){ /* borttagen funktionalitet */ }

function applyTransform(){
  var img = $('#mapLayer'); var overlay = $('#mapOverlay');
  if (!img) return;
  var t = 'translate(' + _mapState.tx + 'px, ' + _mapState.ty + 'px) scale(' + _mapState.scale + ')';
  img.style.transform = t;
  if (overlay) overlay.style.transform = t;
}

function clampPan(){
  var img = $('#mapLayer'); var viewport = $('#mapViewport');
  if (!img || !viewport) return;
  if (!img.naturalWidth || !img.naturalHeight) return;
  var vw = viewport.clientWidth, vh = viewport.clientHeight;
  var iw = img.naturalWidth * _mapState.scale;
  var ih = img.naturalHeight * _mapState.scale;
  if (iw < vw) _mapState.tx = (vw - iw)/2;
  else {
    var minTx = vw - iw; if (_mapState.tx < minTx) _mapState.tx = minTx;
    if (_mapState.tx > 0) _mapState.tx = 0;
  }
  if (ih < vh) _mapState.ty = (vh - ih)/2;
  else {
    var minTy = vh - ih; if (_mapState.ty < minTy) _mapState.ty = minTy;
    if (_mapState.ty > 0) _mapState.ty = 0;
  }
}

function initMapControls(){
  function viewportToPixel(clientX, clientY){
    var viewport = $('#mapViewport');
    if (!viewport) return {px:0, py:0};
    var rect = viewport.getBoundingClientRect();
    var cx = clientX - rect.left, cy = clientY - rect.top;
    var px = (cx - _mapState.tx) / _mapState.scale;
    var py = (cy - _mapState.ty) / _mapState.scale;
    return { px: px, py: py };
  }
  var viewport = $('#mapViewport'); var img = $('#mapLayer');
  if (!viewport || !img) return;
  function resize(){ try{ clampPan(); applyTransform(); }catch(e){} }
  window.addEventListener('resize', resize);

  function onWheel(e){
    try{
      var delta = e.deltaY || 0;
      var factor = delta > 0 ? 0.9 : 1.1;
      var rect = viewport.getBoundingClientRect();
      var cx = e.clientX - rect.left, cy = e.clientY - rect.top;
      var beforeX = (cx - _mapState.tx) / _mapState.scale;
      var beforeY = (cy - _mapState.ty) / _mapState.scale;
      var newScale = _mapState.scale * factor;
      if (newScale < _mapState.min) newScale = _mapState.min;
      if (newScale > _mapState.max) newScale = _mapState.max;
      _mapState.scale = newScale;
      _mapState.tx = cx - beforeX * _mapState.scale;
      _mapState.ty = cy - beforeY * _mapState.scale;
      clampPan(); applyTransform();
      e.preventDefault();
    }catch(ex){}
  }
  viewport.addEventListener('wheel', onWheel, { passive:false });

  var dragging = false, sx=0, sy=0, stx=0, sty=0;
  function onDown(e){
    dragging = true;
    sx = (e.touches && e.touches.length ? e.touches[0].clientX : e.clientX);
    sy = (e.touches && e.touches.length ? e.touches[0].clientY : e.clientY);
    stx = _mapState.tx; sty = _mapState.ty;
    viewport.classList.remove('grab'); viewport.classList.add('grabbing');
  }
  function onMove(e){
    if (!dragging) return;
    var cx = (e.touches && e.touches.length ? e.touches[0].clientX : e.clientX);
    var cy = (e.touches && e.touches.length ? e.touches[0].clientY : e.clientY);
    _mapState.tx = stx + (cx - sx);
    _mapState.ty = sty + (cy - sy);
    clampPan(); applyTransform();
  }
  function onUp(){
    dragging = false;
    viewport.classList.remove('grabbing'); viewport.classList.add('grab');
  }
  viewport.addEventListener('mousedown', onDown);
  window.addEventListener('mousemove', onMove);
  window.addEventListener('mouseup', onUp);
  viewport.addEventListener('touchstart', onDown, {passive:false});
  viewport.addEventListener('touchmove', onMove, {passive:false});
  viewport.addEventListener('touchend', onUp);

  // Klick för pick-kalibrering borttagen
  viewport.addEventListener('click', function(ev){
    if (!__pickMode) return;
  });

  var zin = $('#zoomInBtn'), zout = $('#zoomOutBtn'), zreset = $('#resetViewBtn');
  if (zin) zin.onclick = function(){ _mapState.scale *= 1.1; if (_mapState.scale > _mapState.max) _mapState.scale = _mapState.max; clampPan(); applyTransform(); };
  if (zout) zout.onclick = function(){ _mapState.scale *= 0.9; if (_mapState.scale < _mapState.min) _mapState.scale = _mapState.min; clampPan(); applyTransform(); };
  if (zreset) zreset.onclick = function(){ _mapState.scale = 1.6; _mapState.tx = 0; _mapState.ty = 0; clampPan(); applyTransform(); };

  clampPan(); applyTransform();
}

function resetMap(){
  showPanel();
  var root = $('#view-territories'); if (!root) return;
  root.innerHTML = ''
    + '<div class="card">'
    + '  <h3 style="display:flex;align-items:center;justify-content:space-between;gap:8px">'
    + '    <span>Territorier</span>'
    + '    <span></span>'
    + '  </h3>'
    + '  <div id="mapViewport" class="map-viewport grab" aria-label="Karta">'
    + '    <img id="mapLayer" class="map-layer" src="gta5_map_full.png" alt="GTA V karta (full)"/>'
    + '    <div id="mapOverlay" class="map-layer"></div>' + 
    + '    <div class="map-controls">'
    + '      <button id="zoomInBtn" title="Zooma in +">+</button>'
    + '      <button id="zoomOutBtn" title="Zooma ut −">−</button>'
    + '      <button id="resetViewBtn" title="Återställ vy">⟳</button>'
    + '      <button id="followBtn" title="Följ spelare">◎</button>'
    + '      <button id="jumpToBtn" title="Hoppa till spelare">⇱</button>'
    + '    </div>'
    + '    <div class="map-hint">Scrolla för att zooma • Dra för att panorera</div>'
    + '  </div>'
    + '</div>';

  initMapControls();
  // Rita ev. tidigare mottagna områden
  if (window.__areasLatest && window.__areasLatest.length){ try{ window.setAreas(window.__areasLatest); }catch(e){} }



  // Pick-badge/toast borttagen


  var fb = $('#followBtn'); if (fb){ fb.style.background = 'rgba(255,255,255,.1)'; fb.addEventListener('click', function(){ _followPlayer = !_followPlayer; fb.style.background = _followPlayer ? 'rgba(108,140,255,.35)' : 'rgba(255,255,255,.1)'; if (_followPlayer && window.__lastPlayer){ centerOnPixel(window.__lastPlayer.x, window.__lastPlayer.y); } }); }
  var jb = $('#jumpToBtn'); if (jb){ jb.addEventListener('click', function(){ if (window.__lastPlayer) centerOnPixel(window.__lastPlayer.x, window.__lastPlayer.y); }); }
}

function centerOnPixel(px, py){
  var viewport = $('#mapViewport'); var img = $('#mapLayer');
  if (!viewport || !img) return;
  var rect = viewport.getBoundingClientRect();
  var s = _mapState.scale || 1;
  _mapState.tx = (rect.width/2) - (px * s);
  _mapState.ty = (rect.height/2) - (py * s);
  clampPan(); applyTransform();
}

function ensureOverlay(){ return $('#mapOverlay'); }
function addMarker(px, py, label){
  var overlay = ensureOverlay(); if (!overlay) return;
  var el = document.createElement('div');
  el.className = 'marker';
  el.style.left = px + 'px';
  el.style.top  = py + 'px';
  el.innerHTML = '<div class="dot"></div><div class="mlabel">' + (label||'Marker') + '</div>';
  overlay.appendChild(el);
  state.markers.push({ x:px, y:py, label:label||'Marker' });
}
function clearMarkers(){
  var overlay = ensureOverlay(); if (!overlay) return;
  while (overlay.firstChild) overlay.removeChild(overlay.firstChild);
  state.markers = [];
}

function setPlayerMarker(px, py, heading, label){
  if (!$('#mapViewport')){ window.__lastPlayer = { x:px, y:py, heading:heading||0, label:label||'Player' }; return; }
  var overlay = ensureOverlay(); if (!overlay) return;
  var el = document.getElementById('playerMarker');
  if (!el){
    el = document.createElement('div');
    el.id = 'playerMarker';
    el.className = 'marker player';
    el.innerHTML = '<div class="arrow"></div><div class="mlabel">' + (label||'Player') + '</div>';
    overlay.appendChild(el);
  }
  el.style.left = px + 'px';
  el.style.top  = py + 'px';
  var rot = (typeof heading === 'number' ? -heading : 0);
  el.style.transform = 'translate(-10px,-10px) rotate(' + rot.toFixed(1) + 'deg)';
  window.__lastPlayer = { x:px, y:py, heading:heading||0, label:label||'Player' };
  if (_followPlayer) centerOnPixel(px, py);
}
function removePlayerMarker(){
  var el = document.getElementById('playerMarker');
  if (el && el.parentNode) el.parentNode.removeChild(el);
}

var _followPlayer = false;

function nuiClose(){
  try { fetch('https://ct-gang/close', {method:'POST', headers:{'Content-Type':'application/json'}, body:'{}'}); } catch(e){}
  hidePanel();
}


window.addEventListener('message', function(e){
  var msg = e && e.data ? e.data : {};
  if (msg.action === 'setGang' && msg.data){ state.gang = msg.data; state.gangLabel = ((msg.data && (msg.data.label || msg.data.name)) || ''); render(); }

  if (msg.action === 'close'){ hidePanel(); return; }
  if (msg.action === 'addMarker'){ addMarker(msg.x, msg.y, msg.label); if (currentTab !== 'territories'){ setTab('territories'); } }
  if (msg.action === 'setPlayerMarker'){ setPlayerMarker(msg.x, msg.y, msg.heading, msg.label); }
  if (msg.action === 'removePlayerMarker'){ removePlayerMarker(); }
  if (msg.action === 'switchTab'){ showPanel(); setTab(msg.tab || 'overview'); }
  if (msg.action === 'clearMarkers'){ clearMarkers(); }
  if (msg.action === 'snapshot'){ var d=msg.data||{}; for (var k in d){ state[k]=d[k]; } if (!state.gang && state.PlayerData && state.PlayerData.gang){ state.gang = state.PlayerData.gang; } showPanel(); render(); }
  if (msg.action === 'update' && msg.data){ var u=msg.data; for (var k2 in u){ state[k2]=u[k2]; } render(); }
  if (msg.action === 'toast'){ toast(msg.msg || ''); }
});

document.addEventListener('keydown', function(ev){
  try{
    if (ev.key === 'Escape'){
      try { fetch('https://ct-gang/close', {method:'POST', headers:{'Content-Type':'application/json'}, body:'{}'}); } catch(e){}
      hidePanel();
    }
    // Alt+K (pick-mode) borttagen
    if (ev.key && ev.key.toLowerCase() === 'x'){
      var tag = (document.activeElement && document.activeElement.tagName || '').toLowerCase();
      if (tag != 'input' && tag != 'textarea' && !(document.activeElement && document.activeElement.isContentEditable)){
        nuiClose();
        return;
      }
    }
  }catch(e){}
});
render();

// Hook close button (✖)
var _cb = document.getElementById('closeBtn');
if (_cb) _cb.addEventListener('click', function(e){ e.preventDefault(); nuiClose(); });

// ---- Tab button handlers ----
function attachTabHandlers(){
  var btns = document.querySelectorAll('.tabbtn');
  for (var i=0;i<btns.length;i++){
    (function(b){
      b.addEventListener('click', function(ev){
        try{ ev.preventDefault(); ev.stopPropagation(); }catch(e){}
        var t = b.getAttribute('data-tab') || 'members';
        showPanel();
        setTab(t);
      });
    })(btns[i]);
  }
}
if (document.readyState === 'loading'){
  document.addEventListener('DOMContentLoaded', attachTabHandlers);
} else {
  attachTabHandlers();
}


// === ct-gang: ensure existing house emoji is LEFT of the gang title ===
(function(){
  function moveHouseIconLeft(){
    var titleWrap = document.querySelector('.title');
    var titleEl = document.getElementById('gang-title');
    if(!titleWrap || !titleEl) return;
    // Remove any previously injected extra icons
    titleWrap.querySelectorAll('.gang-icon').forEach(el => el.remove());
    // Find an existing house emoji element in the title bar
    var iconCandidate = null;
    // Prefer a node that only contains the emoji
    Array.from(titleWrap.childNodes).forEach(function(n){
      if(iconCandidate) return;
      // text node containing the house emoji
      if(n.nodeType === Node.TEXT_NODE && /\u{1F3E0}/u.test(n.textContent || '')){
        // wrap it in a span to be movable
        var span = document.createElement('span');
        span.textContent = '🏠';
        span.className = 'gang-icon';
        titleWrap.replaceChild(span, n);
        iconCandidate = span;
      }else if(n.nodeType === Node.ELEMENT_NODE){
        var txt = (n.textContent || '').trim();
        if(/\u{1F3E0}/u.test(txt) && n.id !== 'gang-title'){
          iconCandidate = n;
          n.classList.add('gang-icon');
        }
      }
    });
    if(iconCandidate){
      // Move before the title
      if(iconCandidate !== titleWrap.firstChild){
        titleWrap.insertBefore(iconCandidate, titleEl);
      }
    }
  }

  window.addEventListener('message', function(e){
    var msg = e.data || {};
    if(msg.action === 'open' || msg.action === 'setGang'){
      setTimeout(moveHouseIconLeft, 0);
    }
  });
  document.addEventListener('DOMContentLoaded', moveHouseIconLeft);
})();

// === ct-gang: force title to player's gang ===
(function(){
  let lastGang = null;
  function setTitle(txt){
    var el = document.getElementById('gang-title');
    if(el){ el.textContent = txt || 'Gäng'; }
  }
  window.addEventListener('message', function(e){
    var msg = e.data || {};
    if(msg.action === 'setGang' && msg.data){
      lastGang = (msg.data.label || msg.data.name || 'Gäng');
      setTitle(lastGang);
    }
    if(msg.action === 'open'){ if(typeof __gangLastName !== 'undefined'){ setGangLabel(__gangLastName); }
      setTitle(lastGang || 'Gäng');
    }
  });
})();


// === ct-gang: ensure house emoji is LEFT and remove default text ===
(function(){
  let lastGang = null;
  function moveHouseLeft(){
    const wrap = document.querySelector('.title');
    const title = document.getElementById('gang-title');
    if(!wrap || !title) return;
    // find an existing element (or text node) that includes the house emoji
    const HOUSE = '🏠';
    let iconEl = null;
    // Search elements first
    const children = Array.from(wrap.childNodes);
    for (const n of children){
      if (n === title) continue;
      const txt = (n.textContent || '').trim();
      if (txt.includes(HOUSE)) { iconEl = n; break; }
    }
    // If it's a text node, wrap it
    if(iconEl && iconEl.nodeType === Node.TEXT_NODE){
      const span = document.createElement('span');
      span.textContent = HOUSE;
      span.className = 'gang-icon';
      wrap.replaceChild(span, iconEl);
      iconEl = span;
    }
    if(iconEl){
      // Move emoji before the title
      if (iconEl.nextSibling !== title) {
        wrap.insertBefore(iconEl, title);
      }
      // tidy spacing via class
      iconEl.classList.add('gang-icon');
    }
  }

  function setTitle(txt){
    const el = document.getElementById('gang-title');
    if(el){ el.textContent = txt || ''; __gangLastName = txt || __gangLastName; } // no default "Gäng" text
  }

  window.addEventListener('message', function(e){
    const msg = e.data || {};
    if(msg.action === 'setGang' && msg.data){
      lastGang = (msg.data.label || msg.data.name || '');
      setTitle(lastGang);
      moveHouseLeft();
    }
    if(msg.action === 'open'){ if(typeof __gangLastName !== 'undefined'){ setGangLabel(__gangLastName); }
      setTitle(lastGang || '');
      moveHouseLeft();
    }
  });

  document.addEventListener('DOMContentLoaded', moveHouseLeft);
})();


// === ct-gang: keep gang label always set & emoji on the LEFT ===
(function(){
  let lastGang = null;

  var __gangLastName = '';
function setGangLabel(txt){
    const el = document.getElementById('gangLabel');
    if(el){
      el.textContent = txt || ''; __gangLastName = txt || __gangLastName; // no "Gäng" fallback
    }
  }

  function moveHouseLeft(){
    const el = document.getElementById('gangLabel');
    if(!el) return;
    const wrap = el.parentElement || document.querySelector('.title') || document.body;
    const HOUSE = '🏠';
    let iconEl = null;

    // Find a sibling element containing the house emoji
    const nodes = Array.from(wrap.childNodes);
    for (const n of nodes){
      if (n === el) continue;
      const txt = (n.textContent || '').trim();
      if (txt.includes(HOUSE)){
        iconEl = n;
        break;
      }
    }
    if(!iconEl) return;

    // If the emoji is a text node, wrap it for layout
    if(iconEl.nodeType === Node.TEXT_NODE){
      const span = document.createElement('span');
      span.textContent = HOUSE;
      span.className = 'gang-icon';
      wrap.replaceChild(span, iconEl);
      iconEl = span;
    }else{
      iconEl.classList.add('gang-icon');
    }

    // Insert before gang label to force LEFT
    if(iconEl.nextSibling !== el){
      wrap.insertBefore(iconEl, el);
    }
  }

  window.addEventListener('message', function(e){
    const msg = e.data || {};
    if(msg.action === 'setGang' && msg.data){
      lastGang = (msg.data.label || msg.data.name || '');
      setGangLabel(lastGang);
      moveHouseLeft();
    }
    if(msg.action === 'open'){ if(typeof __gangLastName !== 'undefined'){ setGangLabel(__gangLastName); }
      // keep what we know; avoid "Gäng"
      setGangLabel(lastGang || '');
      moveHouseLeft();
    }
  });

  document.addEventListener('DOMContentLoaded', function(){
    // Ask client to refresh gang so NUI has value after resource restart
    try { window.postMessage({ action: 'ct-gang:requestRefresh' }, '*'); } catch(e){}
    moveHouseLeft();
  });
})();


// === ct-gang: enforce '(🏠) {Gang}' order and purge old 'Gäng' label ===
(function(){
  function purgeOldGangText(wrap, keepEl){
    if(!wrap) return;
    const toRemove = [];
    wrap.childNodes.forEach(n => {
      if(n === keepEl) return;
      const txt = (n.textContent || '').trim();
      if (txt === 'Gäng') toRemove.push(n);
    });
    toRemove.forEach(n => n.parentNode && n.parentNode.removeChild(n));
  }

  function moveHouseLeft(){
    const label = document.getElementById('gangLabel');
    if(!label) return;
    const wrap = label.parentElement;
    const HOUSE = '🏠';
    let iconEl = null;

    // Find node with house
    const nodes = Array.from(wrap.childNodes);
    for (const n of nodes){
      if (n === label) continue;
      const txt = (n.textContent || '').trim();
      if (txt.includes(HOUSE)){
        iconEl = n; break;
      }
    }
    if(iconEl){
      // Wrap text node if needed
      if(iconEl.nodeType === Node.TEXT_NODE){
        const span = document.createElement('span');
        span.textContent = HOUSE;
        span.className = 'gang-icon';
        wrap.replaceChild(span, iconEl);
        iconEl = span;
      } else {
        iconEl.classList.add('gang-icon');
        iconEl.textContent = HOUSE; // normalize to just the house
      }
      // Insert BEFORE label => (🏠) {Gang}
      if(iconEl.nextSibling !== label){
        wrap.insertBefore(iconEl, label);
      }
    }
    // Remove any leftover 'Gäng' nodes
    purgeOldGangText(wrap, label);
  }

  var __gangLastName = '';
function setGangLabel(txt){
    const el = document.getElementById('gangLabel');
    if(el){ el.textContent = txt || ''; __gangLastName = txt || __gangLastName; }
  }

  // Hook messages
  window.addEventListener('message', function(e){
    const msg = e.data || {};
    if(msg.action === 'setGang' && msg.data){
      const gtxt = (msg.data.label || msg.data.name || '');
      setGangLabel(gtxt);
      moveHouseLeft();
    }
    if(msg.action === 'open'){ if(typeof __gangLastName !== 'undefined'){ setGangLabel(__gangLastName); }
      moveHouseLeft();
    }
  });

  document.addEventListener('DOMContentLoaded', moveHouseLeft);
})();



// === ct-gang: draw polygons on territories map (integrated) ===
(function(){
  var drawing = false;
  var points = [];
  var polyEl = null;
  var dots = [];
  var svgEl = null;

  function ensureSVG(){
    var overlay = document.getElementById('mapOverlay');
    if (!overlay) return null;
    if (!svgEl){
      svgEl = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      svgEl.setAttribute('id', 'polySvg');
      svgEl.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
      svgEl.style.position = 'absolute';
      svgEl.style.left = '0'; svgEl.style.top = '0';
      svgEl.style.width = '100%'; svgEl.style.height = '100%';
      svgEl.style.overflow = 'visible';
      overlay.appendChild(svgEl);
    }
    return svgEl;
  }

  function pxFromClient(clientX, clientY){
    var viewport = document.getElementById('mapViewport');
    if (!viewport) return {x:0,y:0};
    var rect = viewport.getBoundingClientRect();
    var cx = clientX - rect.left, cy = clientY - rect.top;
    var px = (cx - (_mapState.tx||0)) / (_mapState.scale||1);
    var py = (cy - (_mapState.ty||0)) / (_mapState.scale||1);
    return { x: px, y: py };
  }

  function redraw(){
    var svg = ensureSVG(); if (!svg) return;
    if (!polyEl){
      polyEl = document.createElementNS('http://www.w3.org/2000/svg', 'polyline');
      polyEl.setAttribute('fill', 'rgba(0, 150, 255, 0.15)');
      polyEl.setAttribute('stroke', 'rgba(0, 150, 255, 0.9)');
      polyEl.setAttribute('stroke-width', '2');
      svg.appendChild(polyEl);
    }
    polyEl.setAttribute('points', points.map(p => p.x + ',' + p.y).join(' '));

    dots.forEach(d => d.remove()); dots = [];
    points.forEach(p => {
      var c = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
      c.setAttribute('cx', p.x); c.setAttribute('cy', p.y);
      c.setAttribute('r', '4'); c.setAttribute('fill', 'rgba(0,150,255,1)');
      ensureSVG().appendChild(c);
      dots.push(c);
    });
  }

  function start(){
    drawing = true; points = [];
    if (polyEl){ polyEl.remove(); polyEl = null; }
    dots.forEach(d => d.remove()); dots = [];
    var f = document.getElementById('finishPolyBtn');
    if (f) f.style.display = '';
  }
  function cancel(){
    drawing = false; points = [];
    if (polyEl){ polyEl.remove(); polyEl = null; }
    dots.forEach(d => d.remove()); dots = [];
    var f = document.getElementById('finishPolyBtn');
    if (f) f.style.display = 'none';
  }
  function finish(){
    if (points.length < 3){ cancel(); return; }
    polyEl && polyEl.setAttribute('points', points.concat([points[0]]).map(p => p.x + ',' + p.y).join(' '));
    var cx = points.reduce((s,p)=>s+p.x,0)/points.length;
    var cy = points.reduce((s,p)=>s+p.y,0)/points.length;
    var t = document.createElementNS('http://www.w3.org/2000/svg', 'text');
    t.setAttribute('x', cx); t.setAttribute('y', cy);
    t.setAttribute('font-size','14'); t.setAttribute('text-anchor','middle');
    t.setAttribute('fill','white'); t.setAttribute('stroke','black'); t.setAttribute('stroke-width','0.75');
    t.textContent = 'Område (' + points.length + 'p)';
    ensureSVG().appendChild(t);

    var wpts = points.map(function(p){
      if (window.CTGang && typeof window.CTGang.pixelToWorld === 'function') return window.CTGang.pixelToWorld(p.x, p.y);
      return {x:p.x, y:p.y};
    });
    try{
      fetch('https://ct-gang/saveArea', { method:'POST', headers:{'Content-Type':'application/json; charset=UTF-8'},
        body: JSON.stringify({ action:'saveArea', polygon_world:wpts, polygon_pixels:points })
      });
    }catch(e){}

    drawing = false;
    var f = document.getElementById('finishPolyBtn'); if (f) f.style.display = 'none';
  }

  var _origResetMap = window.resetMap;
  window.resetMap = function(){
    _origResetMap.apply(this, arguments);
    var ctrls = document.querySelector('.map-controls');
    if (ctrls && !document.getElementById('drawPolyBtn')){
      var b = document.createElement('button'); b.id='drawPolyBtn'; b.title='Rita område'; b.textContent='▱';
      var s = document.createElement('button'); s.id='finishPolyBtn'; s.title='Spara område'; s.textContent='✔'; s.style.display='none';
      ctrls.appendChild(b); ctrls.appendChild(s);
      b.addEventListener('click', function(ev){ ev.preventDefault(); ev.stopPropagation(); start(); });
      s.addEventListener('click', function(ev){ ev.preventDefault(); ev.stopPropagation(); finish(); });
    }

    var viewport = document.getElementById('mapViewport');
    if (viewport){
      viewport.addEventListener('mousedown', function(e){
        if (!drawing || e.button !== 0) return;
        var p = pxFromClient(e.clientX, e.clientY);
        points.push({x:p.x, y:p.y}); redraw();
      });
    }

    window.addEventListener('keydown', function(e){
      if (!drawing) return;
      if (e.key === 'Backspace'){ points.pop(); if (points.length===0) cancel(); else redraw(); e.preventDefault(); }
      if (e.key === 'Enter'){ finish(); e.preventDefault(); }
      if (e.key === 'Escape'){ cancel(); e.preventDefault(); }
    });
  };
})();



// === ct-gang: draw polygons (key '1' add point) ===
(function(){
  var drawing = false;
  var points = [];
  var polyEl = null;
  var dots = [];
  var svgEl = null;
  var lastMouse = {x:0, y:0}; // client coords within viewport

  function ensureSVG(){
    var overlay = document.getElementById('mapOverlay');
    var img = document.getElementById('mapLayer');
    if (!overlay || !img) return null;
    if (!svgEl){
      svgEl = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      svgEl.setAttribute('id', 'polySvg');
      svgEl.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
      svgEl.style.position = 'absolute';
      svgEl.style.left = '0'; svgEl.style.top = '0';
      // Size SVG to image's intrinsic pixel space so coordinates match addMarker()
      var w = img.naturalWidth || 4096, h = img.naturalHeight || 4096;
      svgEl.setAttribute('width', w);
      svgEl.setAttribute('height', h);
      svgEl.setAttribute('viewBox', '0 0 ' + w + ' ' + h);
      svgEl.style.pointerEvents = 'none';
      overlay.appendChild(svgEl);
    }
    return svgEl;
  }

  function pxFromClient(clientX, clientY){
    var viewport = document.getElementById('mapViewport');
    if (!viewport) return {x:0,y:0};
    var rect = viewport.getBoundingClientRect();
    var cx = clientX - rect.left, cy = clientY - rect.top;
    var px = (cx - (_mapState.tx||0)) / (_mapState.scale||1);
    var py = (cy - (_mapState.ty||0)) / (_mapState.scale||1);
    return { x: px, y: py };
  }

  function redraw(){
    var svg = ensureSVG(); if (!svg) return;
    if (!polyEl){
      polyEl = document.createElementNS('http://www.w3.org/2000/svg', 'polyline');
      polyEl.setAttribute('fill', 'rgba(0, 150, 255, 0.18)');
      polyEl.setAttribute('stroke', 'rgba(0, 150, 255, 0.95)');
      polyEl.setAttribute('stroke-width', '3');
      svg.appendChild(polyEl);
    }
    polyEl.setAttribute('points', points.map(function(p){ return p.x + ',' + p.y; }).join(' '));

    dots.forEach(function(d){ d.remove(); }); dots = [];
    points.forEach(function(p){
      var c = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
      c.setAttribute('cx', p.x); c.setAttribute('cy', p.y);
      c.setAttribute('r', '5'); c.setAttribute('fill', 'rgba(0,150,255,1)');
      ensureSVG().appendChild(c); dots.push(c);
    });
  }

  function start(){
    drawing = true; points = [];
    if (polyEl){ polyEl.remove(); polyEl = null; }
    dots.forEach(function(d){ d.remove(); }); dots = [];
    var s = document.getElementById('finishPolyBtn'); if (s) s.style.display = '';
  }
  function cancel(){
    drawing = false; points = [];
    if (polyEl){ polyEl.remove(); polyEl = null; }
    dots.forEach(function(d){ d.remove(); }); dots = [];
    var s = document.getElementById('finishPolyBtn'); if (s) s.style.display = 'none';
  }
  function finish(){
    if (points.length < 2){ cancel(); return; }
    // close if 3+ points
    if (points.length >= 3 && polyEl){
      polyEl.setAttribute('points', points.concat([points[0]]).map(function(p){ return p.x + ',' + p.y; }).join(' '));
    }
    var cx = points.reduce(function(s,p){ return s+p.x; },0)/points.length;
    var cy = points.reduce(function(s,p){ return s+p.y; },0)/points.length;
    var t = document.createElementNS('http://www.w3.org/2000/svg', 'text');
    t.setAttribute('x', cx); t.setAttribute('y', cy);
    t.setAttribute('font-size','14'); t.setAttribute('text-anchor','middle');
    t.setAttribute('fill','white'); t.setAttribute('stroke','black'); t.setAttribute('stroke-width','0.75');
    t.textContent = 'Område (' + points.length + 'p)';
    ensureSVG().appendChild(t);

    // Optional: send to Lua for broadcast/persist
    var wpts = points.map(function(p){
      if (window.CTGang && typeof window.CTGang.pixelToWorld === 'function') return window.CTGang.pixelToWorld(p.x, p.y);
      return {x:p.x, y:p.y};
    });
    try{
      fetch('https://ct-gang/saveArea', { method:'POST', headers:{'Content-Type':'application/json; charset=UTF-8'},
        body: JSON.stringify({ action:'saveArea', polygon_world:wpts, polygon_pixels:points })
      });
    }catch(e){}

    drawing = false; var s = document.getElementById('finishPolyBtn'); if (s) s.style.display = 'none';
  }

  // Hook into resetMap to add buttons and wire listeners, preserving your UI
  var _origResetMap = window.resetMap;
  window.resetMap = function(){
    _origResetMap.apply(this, arguments);

    var ctrls = document.querySelector('.map-controls');
    if (ctrls && !document.getElementById('drawPolyBtn')){
      var b = document.createElement('button'); b.id='drawPolyBtn'; b.title='Rita område (tryck 1 för punkt)'; b.textContent='▱';
      var s = document.createElement('button'); s.id='finishPolyBtn'; s.title='Spara område'; s.textContent='✔'; s.style.display='none';
      ctrls.appendChild(b); ctrls.appendChild(s);
      b.addEventListener('click', function(ev){ ev.preventDefault(); ev.stopPropagation(); start(); });
      s.addEventListener('click', function(ev){ ev.preventDefault(); ev.stopPropagation(); finish(); });
    }

    var viewport = document.getElementById('mapViewport');
    if (viewport){
      viewport.addEventListener('mousemove', function(e){
        // track mouse for key '1' placement
        lastMouse = { x: e.clientX, y: e.clientY };
      });
      // IMPORTANT: do NOT place points on left click anymore.
    }

    // Keyboard controls
    window.addEventListener('keydown', function(e){
      if (e.key === '1'){
        // start drawing automatically if not already
        if (!drawing) start();
        var p = pxFromClient(lastMouse.x, lastMouse.y);
        points.push({x:p.x, y:p.y}); redraw(); e.preventDefault();
      } else if (drawing && e.key === 'Backspace'){
        points.pop(); if (points.length===0) cancel(); else redraw(); e.preventDefault();
      } else if (drawing && e.key === 'Enter'){
        finish(); e.preventDefault();
      } else if (drawing && e.key === 'Escape'){
        cancel(); e.preventDefault();
      }
    });
  };
})();


// === OVERRIDE: Use the SAME affine world->pixel as client.lua so config polygons show correctly ===
(function(){
  function worldToPixelAffine(x, y){
    var a11 = 0.151798598000, a12 = 0.00000349709, t1 = 627.884751;
    var a21 = -0.000609547131, a22 = -0.151636800, t2 = 1275.04431;
    var u = a11 * x + a12 * y + t1;
    var v = a21 * x + a22 * y + t2;
    return { x: u, y: v };
  }
  // Force override (NUI-only) so setAreas() uses this projector
  window.worldToPixel = worldToPixelAffine;
  window.CTGang = window.CTGang || {};
  window.CTGang.worldToPixel = worldToPixelAffine;
  if (typeof window.CTGang.pixelToWorld !== 'function'){
    // also expose the inverse using the matrix defined in app.js (if available)
    try{
      var Affine = window.Affine || { a11:0.151798598000, a12:0.00000349709, a21:-0.000609547131, a22:-0.151636800, t1:627.884751, t2:1275.04431 };
      window.CTGang.pixelToWorld = function(u, v){
        var du = u - (Affine.t1 || 627.884751);
        var dv = v - (Affine.t2 || 1275.04431);
        var det = (Affine.a11||0.151798598000)*(Affine.a22||-0.151636800) - (Affine.a12||0.00000349709)*(Affine.a21||-0.000609547131);
        if (!det) return {x:0,y:0};
        var x = ( du*(Affine.a22||-0.151636800) - (Affine.a12||0.00000349709)*dv) / det;
        var y = ( (Affine.a11||0.151798598000)*dv - du*(Affine.a21||-0.000609547131) ) / det;
        return { x:x, y:y };
      };
    }catch(e){}
  }
})(); 

// === HUD (prompt + capture timer) ===
(function(){
  const promptEl = document.getElementById('hudPrompt');
  const promptText = document.getElementById('hudPromptText');
  const capEl = document.getElementById('hudCapture');
  const capFill = document.getElementById('capFill');
  const capTitle = document.getElementById('capTitle');
  const capTime = document.getElementById('capTime');

  let capTotal = 0;
  let capRemaining = 0;

  function showPrompt(text){
    if(promptText){ promptText.textContent = text || ''; }
    if(promptEl){ promptEl.classList.remove('hidden'); }
  }
  function hidePrompt(){
    if(promptEl){ promptEl.classList.add('hidden'); }
  }

  function startTimer(title, totalSec){
    capTotal = Math.max(1, totalSec|0);
    capRemaining = capTotal;
    if(capTitle) capTitle.textContent = title || '';
    if(capEl) capEl.classList.remove('hidden');
    updateTimer(capRemaining);
  }
  function updateTimer(remSec){
    capRemaining = Math.max(0, remSec|0);
    const pct = capTotal ? (100 * (capTotal - capRemaining) / capTotal) : 0;
    if(capFill) capFill.style.width = pct.toFixed(1) + '%';
    if(capTime) capTime.textContent = capRemaining + 's';
    if (capRemaining <= 0){
      endTimer();
    }
  }
  function endTimer(){
    if(capEl) capEl.classList.add('hidden');
    if(capFill) capFill.style.width = '0%';
    capTotal = 0; capRemaining = 0;
  }

  window.addEventListener('message', function(ev){
    const d = ev.data || {};
    if (d.action === 'hud:prompt') {
      if (d.show) showPrompt(d.text || ''); else hidePrompt();
    } else if (d.action === 'hud:timerStart') {
      startTimer(d.title || '', d.total || 5);
    } else if (d.action === 'hud:timerUpdate') {
      updateTimer(d.remaining || 0);
    } else if (d.action === 'hud:timerEnd') {
      endTimer();
    }
  });

  // expose for quick debug in browser
  window.CTHUD = { showPrompt, hidePrompt, startTimer, updateTimer, endTimer };
})();

// === CT-GANG: Minimal Shop Injector (restore button + view) ===
(function(){
  function ensureShopNodes(){
    const sidebar = document.querySelector('.sidebar') || document.querySelector('aside') || document.body;
    const content = document.querySelector('main.content') || document.querySelector('main') || document.body;

    if (!document.getElementById('view-shop')){
      const view = document.createElement('section');
      view.id = 'view-shop'; view.className = 'hidden';
      const anchorView = document.querySelector('section[id^="view-"]') || content;
      (anchorView.parentNode || content).insertBefore(view, anchorView.nextSibling);
    }
    if (!document.getElementById('toolbar-shop')){
      const tb = document.createElement('div');
      tb.id = 'toolbar-shop'; tb.className = 'toolbar hidden';
      tb.innerHTML = '<div class="tokens">G-mynt: <span id="gTokensToolbar">0</span></div>';
      const anchorTb = document.querySelector('.toolbar') || content;
      (anchorTb.parentNode || content).insertBefore(tb, anchorTb.nextSibling);
    }
    if (!document.querySelector('[data-tab="shop"]')){
      const btn = document.createElement('button');
      btn.className = (document.querySelector('.tabbtn') ? 'tabbtn' : 'btn');
      btn.setAttribute('data-tab','shop');
      btn.innerHTML = '<span class="dot"></span><span class="label">Territorier Affär</span>';
      btn.addEventListener('click', function(){ if (typeof window.setTab === 'function') window.setTab('shop'); });

      const buttons = Array.from((sidebar||document).querySelectorAll('button'));
      let inserted = false;
      for (const b of buttons){
        const t = (b.textContent||'').trim().toLowerCase();
        if (t.includes('territoriet') || t.includes('territorier')){
          b.parentNode.insertBefore(btn, b.nextSibling);
          inserted = true; break;
        }
      }
      if (!inserted) (sidebar||document.body).appendChild(btn);
    }
  }

  const ShopState = { tokens: 0 };
  function renderShop(){
    const root = document.getElementById('view-shop'); if(!root) return;
    const t = Number(ShopState.tokens||0);
    const tb = document.getElementById('gTokensToolbar'); if (tb) tb.textContent = t;
    root.innerHTML = ''
      + '<div class="grid cols-3">'
      + '  <div class="card"><h3>G-mynt</h3><div class="stat" id="gTokensStat">'+t+'</div></div>'
      + '  <div class="card">'
      + '    <h3>Territorium Shop</h3>'
      + '    <table><thead><tr><th>Vara</th><th>Pris</th><th></th></tr></thead>'
      + '      <tbody>'
      + '        <tr><td>Mobil</td><td>1 g-mynt</td>'
      + '          <td><button class="btn" id="buyPhoneBtn" '+(t<1?'disabled':'')+'>Köp</button></td></tr>'
      + '      </tbody>'
      + '    </table>'
      + '  </div>'
      + '</div>';
    const btn = document.getElementById('buyPhoneBtn');
    if(btn){
      btn.addEventListener('click', function(e){
        e.preventDefault();
        try { fetch('https://ct-gang/shopBuy', {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ item:'phone' })}); } catch(_){}
      });
    }
  }

  const origSetTab = window.setTab;
  window.setTab = function(name){
    ensureShopNodes();
    if (typeof origSetTab === 'function'){
      try { origSetTab.apply(this, arguments); } catch(e){}
    }
    const view = document.getElementById('view-shop');
    const tb = document.getElementById('toolbar-shop');
    if (view && tb){
      const show = (name === 'shop');
      view.classList.toggle('hidden', !show);
      tb.classList.toggle('hidden', !show);
      if (show){
        try { fetch('https://ct-gang/shopGet', { method:'POST', headers:{'Content-Type':'application/json'}, body:'{}' }); } catch(_){}
      }
    }
  };

  window.addEventListener('message', (ev)=>{
    const msg = ev.data || {};
    if (msg.action === 'update' && msg.data && msg.data.shop && typeof msg.data.shop.tokens === 'number'){
      const v = Number(msg.data.shop.tokens||0);
      ShopState.tokens = v;
      const tb = document.getElementById('gTokensToolbar'); if (tb) tb.textContent = v;
      const view = document.getElementById('view-shop'); if (view && !view.classList.contains('hidden')) renderShop();
    }
  });

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', ensureShopNodes);
  else ensureShopNodes();
})();
// === END shop injector ===

