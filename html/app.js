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
    + '    <div id="mapOverlay" class="map-layer"></div>'
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
