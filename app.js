// State Variables
let tileW = 600; // mm
let tileH = 600; // mm
let jointW = 2; // mm

let scale = 0.4; // pixels per mm (dynamically initialized)
let rotation = 0; // radians
let offsetX = 0; // pixels from screen center
let offsetY = 0; // pixels from screen center

let isLocked = false;
let holePlaced = false;
let holeX_mm = 0;
let holeY_mm = 0;
let holeDiameter_mm = 35; // default fi35

// Multi-touch & gesture state
let touchStartDist = 0;
let touchStartScale = 0;
let touchStartOffsetX = 0;
let touchStartOffsetY = 0;
let touchStartPoint = { x: 0, y: 0 };
let touchStartRotation = 0;
let isMultiTouch = false;
let isDraggingHole = false;
let touchStartHoleX = 0;
let touchStartHoleY = 0;
let hasMovedSignificant = false; // To distinguish tap from drag

// Temporary click location for hole placement
let tempHoleX_mm = 0;
let tempHoleY_mm = 0;

// Camera stream variables
let currentStream = null;
let currentDeviceIndex = 0;
let videoDevices = [];

// DOM Elements
const video = document.getElementById('camera-feed');
const canvas = document.getElementById('overlay-canvas');
const ctx = canvas.getContext('2d');
const statusDisplay = document.getElementById('status-display');
const instructionsBar = document.getElementById('instructions-bar');

// Inputs
const inputWidth = document.getElementById('tile-width');
const inputHeight = document.getElementById('tile-height');
const inputJoint = document.getElementById('joint-width');
const sliderRotation = document.getElementById('grid-rotation');
const sliderScale = document.getElementById('grid-scale');

// Labels
const valRotation = document.getElementById('val-rotation');
const valScale = document.getElementById('val-scale');

// Buttons & Panels
const btnLock = document.getElementById('btn-lock');
const btnCamera = document.getElementById('btn-camera');
const btnResetGrid = document.getElementById('btn-reset-grid');
const btnClearHole = document.getElementById('btn-clear-hole');
const panelSetup = document.getElementById('panel-setup');
const panelMeasurements = document.getElementById('panel-measurements');
const refModeCheckbox = document.getElementById('ref-mode-checkbox');

// Dropdown
const fiDropdownContainer = document.getElementById('fi-dropdown-container');
const btnCloseDropdown = document.getElementById('btn-close-dropdown');

// Offscreen canvas for freezing frame
const offscreenCanvas = document.createElement('canvas');
const offscreenCtx = offscreenCanvas.getContext('2d');

// Initialize
window.addEventListener('DOMContentLoaded', () => {
  setupEventListeners();
  initCamera();
  resizeCanvas();
  resetGrid();
});

window.addEventListener('resize', resizeCanvas);

// Setup Event Listeners
function setupEventListeners() {
  // Tile dimensions change
  inputWidth.addEventListener('input', updateTileDimensions);
  inputHeight.addEventListener('input', updateTileDimensions);
  inputJoint.addEventListener('input', updateTileDimensions);

  // Preset Buttons
  document.querySelectorAll('.preset-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      document.querySelectorAll('.preset-btn').forEach(b => b.classList.remove('active'));
      e.target.classList.add('active');
      
      const w = parseInt(e.target.dataset.w);
      const h = parseInt(e.target.dataset.h);
      
      inputWidth.value = w;
      inputHeight.value = h;
      updateTileDimensions();
      resetGrid();
    });
  });

  // Sliders
  sliderRotation.addEventListener('input', (e) => {
    rotation = (parseInt(e.target.value) * Math.PI) / 180;
    valRotation.innerText = `${e.target.value}°`;
    draw();
  });

  sliderScale.addEventListener('input', (e) => {
    // Map 10-500 scale slider to 0.05 - 2.5 scale factor
    scale = parseInt(e.target.value) / 250;
    valScale.innerText = `${Math.round(scale * 250)}%`;
    draw();
  });

  // Buttons
  btnResetGrid.addEventListener('click', resetGrid);
  btnCamera.addEventListener('click', switchCamera);
  btnLock.addEventListener('click', toggleLock);
  btnClearHole.addEventListener('click', removeHole);
  
  // Height reference mode toggle
  refModeCheckbox.addEventListener('change', () => {
    updateMeasurements();
    draw();
  });

  // Nudge Buttons
  document.getElementById('nudge-up').addEventListener('click', () => nudgeHole('up'));
  document.getElementById('nudge-down').addEventListener('click', () => nudgeHole('down'));
  document.getElementById('nudge-left').addEventListener('click', () => nudgeHole('left'));
  document.getElementById('nudge-right').addEventListener('click', () => nudgeHole('right'));

  // Dropdown sizing options
  document.querySelectorAll('.fi-option').forEach(option => {
    option.addEventListener('click', (e) => {
      // Extract numeric fi size from dataset or target text
      const fiVal = parseInt(e.currentTarget.dataset.fi);
      confirmHolePlacement(fiVal);
    });
  });

  btnCloseDropdown.addEventListener('click', () => {
    fiDropdownContainer.classList.add('hidden');
    updateStatus(isLocked ? "Raster zaključan. Kliknite za rupu." : "Sustav spreman");
  });

  // Canvas touch gestures
  canvas.addEventListener('touchstart', handleTouchStart, { passive: false });
  canvas.addEventListener('touchmove', handleTouchMove, { passive: false });
  canvas.addEventListener('touchend', handleTouchEnd, { passive: false });

  // Fallback mouse clicks for testing on Desktop
  canvas.addEventListener('mousedown', handleMouseDown);
  canvas.addEventListener('mousemove', handleMouseMove);
  canvas.addEventListener('mouseup', handleMouseUp);
}

// Camera Functionality
async function initCamera() {
  try {
    const devices = await navigator.mediaDevices.enumerateDevices();
    videoDevices = devices.filter(device => device.kind === 'videoinput');
    
    if (videoDevices.length === 0) {
      updateStatus("Kamera nije pronađena.");
      return;
    }
    
    // Choose back camera if possible
    let backCamIndex = videoDevices.findIndex(d => 
      d.label.toLowerCase().includes('back') || 
      d.label.toLowerCase().includes('environment') || 
      d.label.toLowerCase().includes('stražnja') || 
      d.label.toLowerCase().includes('straga')
    );
    currentDeviceIndex = backCamIndex !== -1 ? backCamIndex : 0;
    
    await startCamera(videoDevices[currentDeviceIndex].deviceId);
  } catch (err) {
    console.error("Camera Init Error:", err);
    updateStatus("Greška s kamerom: " + err.message);
  }
}

async function startCamera(deviceId) {
  if (currentStream) {
    currentStream.getTracks().forEach(track => track.stop());
  }
  
  const constraints = {
    video: {
      deviceId: deviceId ? { exact: deviceId } : undefined,
      facingMode: deviceId ? undefined : 'environment',
      width: { ideal: 1920 },
      height: { ideal: 1080 }
    },
    audio: false
  };
  
  try {
    const stream = await navigator.mediaDevices.getUserMedia(constraints);
    currentStream = stream;
    video.srcObject = stream;
    video.play();
    updateStatus("Kamera aktivna");
  } catch (err) {
    try {
      // Fallback constraints
      const fallbackStream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } });
      currentStream = fallbackStream;
      video.srcObject = fallbackStream;
      video.play();
      updateStatus("Kamera aktivna (rezervna)");
    } catch (fallbackErr) {
      updateStatus("Kamera nedostupna: " + fallbackErr.message);
    }
  }
}

async function switchCamera() {
  if (videoDevices.length <= 1) {
    showToast("Nema drugih dostupnih kamera");
    return;
  }
  currentDeviceIndex = (currentDeviceIndex + 1) % videoDevices.length;
  await startCamera(videoDevices[currentDeviceIndex].deviceId);
  showToast("Promjena kamere...");
}

// Canvas & Grid Setup
function resizeCanvas() {
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
  offscreenCanvas.width = window.innerWidth;
  offscreenCanvas.height = window.innerHeight;
  
  // Re-adjust default scale based on window size
  if (!isLocked) {
    const minDim = Math.min(canvas.width, canvas.height);
    scale = (minDim * 0.45) / tileW; // default scale so one tile fits in 45% of the viewport
    sliderScale.value = Math.round(scale * 250);
    valScale.innerText = `${Math.round(scale * 250)}%`;
  }
  
  draw();
}

function updateTileDimensions() {
  tileW = parseFloat(inputWidth.value) || 600;
  tileH = parseFloat(inputHeight.value) || 600;
  jointW = parseFloat(inputJoint.value) || 2;
  
  // Deactivate active preset if dimensions don't match presets
  let matched = false;
  document.querySelectorAll('.preset-btn').forEach(btn => {
    const w = parseInt(btn.dataset.w);
    const h = parseInt(btn.dataset.h);
    if (w === tileW && h === tileH) {
      btn.classList.add('active');
      matched = true;
    } else {
      btn.classList.remove('active');
    }
  });
  
  if (holePlaced) {
    updateMeasurements();
  }
  draw();
}

function resetGrid() {
  offsetX = 0;
  offsetY = 0;
  rotation = 0;
  
  const minDim = Math.min(canvas.width, canvas.height);
  scale = (minDim * 0.45) / tileW;
  
  sliderRotation.value = 0;
  valRotation.innerText = "0°";
  sliderScale.value = Math.round(scale * 250);
  valScale.innerText = `${Math.round(scale * 250)}%`;
  
  draw();
  showToast("Raster resetiran na sredinu");
}

// Lock & Freeze Toggle
function toggleLock() {
  if (!isLocked) {
    // LOCKING: Freeze Camera frame and Lock Grid
    isLocked = true;
    
    // Capture camera frame to offscreen canvas
    try {
      offscreenCtx.drawImage(video, 0, 0, canvas.width, canvas.height);
      video.pause();
    } catch (e) {
      console.warn("Failed to capture video frame:", e);
    }
    
    btnLock.classList.add('locked');
    btnLock.innerHTML = `<span class="lock-icon">🔒</span><span class="lock-text">Otključaj i Nastavi</span>`;
    
    // Disable grid adjustment controls for clarity
    sliderRotation.disabled = true;
    sliderScale.disabled = true;
    btnResetGrid.disabled = true;
    
    updateStatus("Pogled zamrznut. Kliknite na ekran za postavljanje rupe.");
    instructionsBar.innerText = "Dodirnite točno mjesto na pločici gdje trebate izbušiti rupu.";
    showToast("Pogled zamrznut i zaključan");
  } else {
    // UNLOCKING: Resume camera, hide measurements, clear hole
    isLocked = false;
    
    try {
      video.play();
    } catch (e) {
      console.error("Failed to resume video:", e);
    }
    
    btnLock.classList.remove('locked');
    btnLock.innerHTML = `<span class="lock-icon">🔓</span><span class="lock-text">Zaključaj i Zamrzni</span>`;
    
    // Re-enable grid controls
    sliderRotation.disabled = false;
    sliderScale.disabled = false;
    btnResetGrid.disabled = false;
    
    removeHole();
    
    updateStatus("Kamera aktivna");
    instructionsBar.innerText = "Poravnajte raster s pločicom na ekranu, a zatim pritisnite \"Zaključaj i Zamrzni\".";
    showToast("Pogled otključan");
  }
  draw();
}

// Handle Tap / Mouse Click for Hole placement
function triggerHolePopup(screenX, screenY) {
  // Convert screen coordinates to grid coordinates
  const cx = canvas.width / 2 + offsetX;
  const cy = canvas.height / 2 + offsetY;
  
  const dx = screenX - cx;
  const dy = screenY - cy;
  
  // Rotate back by -rotation
  const rx = dx * Math.cos(-rotation) - dy * Math.sin(-rotation);
  const ry = dx * Math.sin(-rotation) + dy * Math.cos(-rotation);
  
  // Scale back to mm
  tempHoleX_mm = rx / scale;
  tempHoleY_mm = ry / scale;
  
  // Position dropdown popup at the click point
  fiDropdownContainer.classList.remove('hidden');
  
  // Bounding rect calculations
  const dropdownWidth = 320;
  const dropdownHeight = 360;
  let left = screenX - dropdownWidth / 2;
  let top = screenY - dropdownHeight / 2;
  
  // Contain within screen boundaries
  left = Math.max(10, Math.min(window.innerWidth - dropdownWidth - 10, left));
  top = Math.max(10, Math.min(window.innerHeight - dropdownHeight - 10, top));
  
  fiDropdownContainer.style.left = left + 'px';
  fiDropdownContainer.style.top = top + 'px';
  fiDropdownContainer.style.transform = 'none';
  
  updateStatus("Odaberite promjer (Fi) rupe...");
}

function confirmHolePlacement(fiVal) {
  holeDiameter_mm = fiVal;
  holeX_mm = tempHoleX_mm;
  holeY_mm = tempHoleY_mm;
  holePlaced = true;
  
  fiDropdownContainer.classList.add('hidden');
  
  // Update UI Panels
  panelMeasurements.classList.remove('hidden');
  document.getElementById('nudge-center-val').innerText = `Fi${holeDiameter_mm}`;
  
  updateMeasurements();
  draw();
  showToast(`Postavljena rupa promjera fi${holeDiameter_mm}`);
}

function removeHole() {
  holePlaced = false;
  panelMeasurements.classList.add('hidden');
  updateStatus(isLocked ? "Raster zaključan. Kliknite za rupu." : "Sustav spreman");
  draw();
}

// Distance Calculations
function updateMeasurements() {
  if (!holePlaced) return;
  
  const radius = holeDiameter_mm / 2;
  const cellW = tileW + jointW;
  const cellH = tileH + jointW;
  
  // Find which cell the hole center is in
  const col = Math.floor(holeX_mm / cellW);
  const row = Math.floor(holeY_mm / cellH);
  
  // Tile origin relative to grid space (in mm)
  const tx = col * cellW;
  const ty = row * cellH;
  
  // Offset inside the tile cell
  let Cx = holeX_mm - tx;
  let Cy = holeY_mm - ty;
  
  // Snap/cap inside tile dimensions just in case it drifts into joints
  Cx = Math.max(0, Math.min(tileW, Cx));
  Cy = Math.max(0, Math.min(tileH, Cy));
  
  // Distances to tile edges (mm)
  // Left: Cx - radius
  // Right: (tileW - Cx) - radius
  // Top: Cy - radius
  // Bottom: (tileH - Cy) - radius
  const leftDist = Cx - radius;
  const rightDist = tileW - Cx - radius;
  const topDist = Cy - radius;
  const bottomDist = tileH - Cy - radius;
  
  // Update Sidebar values
  document.getElementById('m-left').innerText = `${Math.round(leftDist)} mm`;
  document.getElementById('m-right').innerText = `${Math.round(rightDist)} mm`;
  document.getElementById('m-top').innerText = `${Math.round(topDist)} mm`;
  
  // Handle reference mode for height (bottom tile vs laser line)
  const isLaserMode = refModeCheckbox.checked;
  const bottomLabel = document.getElementById('label-bottom');
  const bottomValue = document.getElementById('m-bottom');
  
  if (isLaserMode) {
    bottomLabel.innerText = "Laser (L)";
    // In laser mode, we might measure from the joint center (laser line is usually set at the joint)
    // so we include the joint width or just measure directly to the bottom border.
    // Let's measure directly to the bottom joint edge (which matches bottom border of tile).
    bottomValue.innerText = `${Math.round(bottomDist)} mm`;
  } else {
    bottomLabel.innerText = "Dolje (D)";
    bottomValue.innerText = `${Math.round(bottomDist)} mm`;
  }
  
  // Update HUD status text
  updateStatus(`Rupa Fi${holeDiameter_mm}: L=${Math.round(leftDist)} D=${Math.round(rightDist)} G=${Math.round(topDist)} D=${Math.round(bottomDist)}`);
}

// Nudge Hole Position
function nudgeHole(direction) {
  if (!holePlaced) return;
  
  const step = parseFloat(document.getElementById('nudge-step').value) || 5;
  
  switch (direction) {
    case 'up':
      holeY_mm -= step;
      break;
    case 'down':
      holeY_mm += step;
      break;
    case 'left':
      holeX_mm -= step;
      break;
    case 'right':
      holeX_mm += step;
      break;
  }
  
  updateMeasurements();
  draw();
}

// Drawing Functions
function draw() {
  // Clear main canvas
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  
  // 1. Draw frozen frame background if locked
  if (isLocked) {
    ctx.drawImage(offscreenCanvas, 0, 0);
  }
  
  // 2. Draw Grid & Dimension overlay
  ctx.save();
  
  // Center grid
  const cx = canvas.width / 2 + offsetX;
  const cy = canvas.height / 2 + offsetY;
  ctx.translate(cx, cy);
  ctx.rotate(rotation);
  
  // Draw Tiles
  drawTiles();
  
  // Draw Hole and Dimensions if placed
  if (holePlaced) {
    drawHoleAndDimensions();
  }
  
  ctx.restore();
}

function drawTiles() {
  const cols = 8;
  const rows = 8;
  const cellW = tileW + jointW;
  const cellH = tileH + jointW;
  
  ctx.save();
  
  for (let c = -cols; c <= cols; c++) {
    for (let r = -rows; r <= rows; r++) {
      const tx = c * cellW * scale;
      const ty = r * cellH * scale;
      const tw = tileW * scale;
      const th = tileH * scale;
      
      // Check if tile is inside viewport to save rendering cost
      // (Simple bounding box check in grid coordinate system is complex, so we just render -8 to +8 which is fast enough)
      
      if (c === 0 && r === 0) {
        // Main highlighted target tile
        ctx.fillStyle = 'rgba(255, 102, 0, 0.07)';
        ctx.strokeStyle = 'rgba(255, 102, 0, 0.7)';
        ctx.lineWidth = 2;
      } else {
        // Rest of the grid
        ctx.fillStyle = 'rgba(255, 255, 255, 0.015)';
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.22)';
        ctx.lineWidth = 1;
      }
      
      ctx.fillRect(tx, ty, tw, th);
      ctx.strokeRect(tx, ty, tw, th);
      
      // Draw grid corner markers for premium HUD feel
      if (c === 0 && r === 0) {
        ctx.fillStyle = '#ff6600';
        ctx.beginPath();
        ctx.arc(0, 0, 4, 0, Math.PI * 2); // Origin dot
        ctx.fill();
      }
    }
  }
  ctx.restore();
}

function drawHoleAndDimensions() {
  const radius_mm = holeDiameter_mm / 2;
  const cellW = tileW + jointW;
  const cellH = tileH + jointW;
  
  const col = Math.floor(holeX_mm / cellW);
  const row = Math.floor(holeY_mm / cellH);
  
  const tx = col * cellW;
  const ty = row * cellH;
  
  // Screen values (in translated coordinate system)
  const hx = holeX_mm * scale;
  const hy = holeY_mm * scale;
  const hr = radius_mm * scale;
  
  const tLeft = tx * scale;
  const tRight = (tx + tileW) * scale;
  const tTop = ty * scale;
  const tBottom = (ty + tileH) * scale;
  
  // 1. Draw Hole circle
  ctx.save();
  ctx.beginPath();
  ctx.arc(hx, hy, hr, 0, Math.PI * 2);
  ctx.fillStyle = 'rgba(255, 61, 0, 0.25)';
  ctx.strokeStyle = '#ff3d00';
  ctx.lineWidth = 2.5;
  ctx.fill();
  ctx.stroke();
  
  // Center crosshair
  ctx.strokeStyle = '#ff3d00';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(hx - 8, hy); ctx.lineTo(hx + 8, hy);
  ctx.moveTo(hx, hy - 8); ctx.lineTo(hx, hy + 8);
  ctx.stroke();
  ctx.restore();
  
  // Helper to draw dashed extension lines if click is outside boundaries
  // (Not common, capped Cx/Cy handles boundaries, but let's draw standard dimension lines)
  
  // Calculate mm values
  const Cx = Math.max(0, Math.min(tileW, holeX_mm - tx));
  const Cy = Math.max(0, Math.min(tileH, holeY_mm - ty));
  const L_dist = Cx - radius_mm;
  const R_dist = tileW - Cx - radius_mm;
  const T_dist = Cy - radius_mm;
  const B_dist = tileH - Cy - radius_mm;
  
  // 2. Draw Dimension Lines with Arrows and Text
  ctx.save();
  
  // Left dimension line
  drawDimensionLine(tLeft, hy, hx - hr, hy, L_dist, 'left');
  
  // Right dimension line
  drawDimensionLine(hx + hr, hy, tRight, hy, R_dist, 'right');
  
  // Top dimension line
  drawDimensionLine(hx, tTop, hx, hy - hr, T_dist, 'top');
  
  // Bottom dimension line
  drawDimensionLine(hx, hy + hr, hx, tBottom, B_dist, 'bottom');
  
  ctx.restore();
}

function drawDimensionLine(x1, y1, x2, y2, value_mm, label) {
  // Don't draw if length is extremely small (meaning hole overlaps border too much, but let's draw it anyway if positive)
  const isNegative = value_mm < 0;
  
  // Dimension line
  ctx.beginPath();
  ctx.moveTo(x1, y1);
  ctx.lineTo(x2, y2);
  ctx.strokeStyle = isNegative ? '#ff3d00' : '#00e676'; // Red for negative overlap, green for valid measurements
  ctx.lineWidth = 1.5;
  
  // Use dashed lines for negative / cut values
  if (isNegative) {
    ctx.setLineDash([4, 4]);
  } else {
    ctx.setLineDash([]);
  }
  ctx.stroke();
  ctx.setLineDash([]); // reset
  
  // Arrow heads
  const angle = Math.atan2(y2 - y1, x2 - x1);
  drawArrowHead(x2, y2, angle, isNegative);
  drawArrowHead(x1, y1, angle + Math.PI, isNegative);
  
  // Draw dimension text badge
  const mx = (x1 + x2) / 2;
  const my = (y1 + y2) / 2;
  
  let textX = mx;
  let textY = my;
  
  // Offset text slightly so it's not directly on the line
  if (x1 === x2) {
    // Vertical line
    textX = mx + 25;
  } else {
    // Horizontal line
    textY = my - 12;
  }
  
  const textStr = `${Math.round(value_mm)} mm`;
  drawBadge(textX, textY, textStr, isNegative);
}

function drawArrowHead(x, y, angle, isNegative) {
  const arrowSize = 7;
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(angle);
  ctx.beginPath();
  ctx.moveTo(0, 0);
  ctx.lineTo(-arrowSize, -arrowSize / 2);
  ctx.lineTo(-arrowSize, arrowSize / 2);
  ctx.closePath();
  ctx.fillStyle = isNegative ? '#ff3d00' : '#00e676';
  ctx.fill();
  ctx.restore();
}

function drawBadge(x, y, text, isNegative) {
  ctx.save();
  ctx.font = 'bold 10px "JetBrains Mono", monospace';
  const textWidth = ctx.measureText(text).width;
  const padX = 5;
  const padY = 2.5;
  const w = textWidth + padX * 2;
  const h = 14 + padY * 2;
  
  // Background
  ctx.fillStyle = isNegative ? 'rgba(255, 61, 0, 0.95)' : 'rgba(13, 16, 23, 0.9)';
  ctx.strokeStyle = isNegative ? '#ff3d00' : '#00e676';
  ctx.lineWidth = 1;
  
  // Draw rounded rect
  drawRoundedRect(x - w / 2, y - h / 2, w, h, 4);
  ctx.fill();
  ctx.stroke();
  
  // Text
  ctx.fillStyle = '#ffffff';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(text, x, y);
  ctx.restore();
}

function drawRoundedRect(x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r);
  ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
}

// Helper Touch Distance
function getTouchDist(e) {
  const dx = e.touches[0].clientX - e.touches[1].clientX;
  const dy = e.touches[0].clientY - e.touches[1].clientY;
  return Math.sqrt(dx * dx + dy * dy);
}

function getTouchMidpoint(e) {
  return {
    x: (e.touches[0].clientX + e.touches[1].clientX) / 2,
    y: (e.touches[0].clientY + e.touches[1].clientY) / 2
  };
}

// Touch Event Handlers
function handleTouchStart(e) {
  e.preventDefault(); // Prevent scrolling / double tap zoom
  hasMovedSignificant = false;
  
  // Close dropdown if clicked outside
  if (!fiDropdownContainer.classList.contains('hidden')) {
    const rect = fiDropdownContainer.getBoundingClientRect();
    const touch = e.touches[0];
    if (touch.clientX < rect.left || touch.clientX > rect.right || touch.clientY < rect.top || touch.clientY > rect.bottom) {
      fiDropdownContainer.classList.add('hidden');
      updateStatus(isLocked ? "Raster zaključan. Kliknite za rupu." : "Sustav spreman");
      return;
    }
  }

  if (e.touches.length === 1) {
    isMultiTouch = false;
    const touch = e.touches[0];
    touchStartPoint = { x: touch.clientX, y: touch.clientY };
    touchStartOffsetX = offsetX;
    touchStartOffsetY = offsetY;
    
    // Check if dragging existing hole (when locked)
    if (isLocked && holePlaced) {
      // Find hole center in screen coords
      const cx = canvas.width / 2 + offsetX;
      const cy = canvas.height / 2 + offsetY;
      
      const hx_px = holeX_mm * scale;
      const hy_px = holeY_mm * scale;
      
      // Rotate by grid rotation
      const r_hx = hx_px * Math.cos(rotation) - hy_px * Math.sin(rotation);
      const r_hy = hx_px * Math.sin(rotation) + hy_px * Math.cos(rotation);
      
      const holeScreenX = r_hx + cx;
      const holeScreenY = r_hy + cy;
      
      // Touch distance to hole center
      const dist = Math.sqrt((touch.clientX - holeScreenX) ** 2 + (touch.clientY - holeScreenY) ** 2);
      
      const radius_px = (holeDiameter_mm / 2) * scale;
      // Allow slightly larger boundary for easy grabbing
      if (dist < Math.max(30, radius_px * 1.5)) {
        isDraggingHole = true;
        touchStartHoleX = holeX_mm;
        touchStartHoleY = holeY_mm;
        showToast("Fino pomicanje rupe");
      }
    }
  } else if (e.touches.length === 2) {
    isMultiTouch = true;
    isDraggingHole = false;
    
    touchStartDist = getTouchDist(e);
    touchStartScale = scale;
    touchStartRotation = rotation;
    
    const midPoint = getTouchMidpoint(e);
    touchStartPoint = midPoint;
    touchStartOffsetX = offsetX;
    touchStartOffsetY = offsetY;
  }
}

function handleTouchMove(e) {
  e.preventDefault();
  
  if (e.touches.length === 1 && !isMultiTouch) {
    const touch = e.touches[0];
    const dx = touch.clientX - touchStartPoint.x;
    const dy = touch.clientY - touchStartPoint.y;
    
    if (Math.abs(dx) > 5 || Math.abs(dy) > 5) {
      hasMovedSignificant = true;
    }
    
    if (isLocked) {
      if (isDraggingHole) {
        // Move the hole!
        // Convert screen delta to rotated grid mm delta
        const rx = dx * Math.cos(-rotation) - dy * Math.sin(-rotation);
        const ry = dx * Math.sin(-rotation) + dy * Math.cos(-rotation);
        
        holeX_mm = touchStartHoleX + rx / scale;
        holeY_mm = touchStartHoleY + ry / scale;
        
        updateMeasurements();
        draw();
      }
    } else {
      // Pan grid
      offsetX = touchStartOffsetX + dx;
      offsetY = touchStartOffsetY + dy;
      draw();
    }
  } else if (e.touches.length === 2 && isMultiTouch) {
    hasMovedSignificant = true;
    
    // Zoom (Pinch)
    const dist = getTouchDist(e);
    const newScale = touchStartScale * (dist / touchStartDist);
    // Cap scale
    scale = Math.max(0.04, Math.min(2.5, newScale));
    
    // Update sliders
    sliderScale.value = Math.round(scale * 250);
    valScale.innerText = `${Math.round(scale * 250)}%`;
    
    // Pan midpoint shift
    const mid = getTouchMidpoint(e);
    offsetX = touchStartOffsetX + (mid.x - touchStartPoint.x);
    offsetY = touchStartOffsetY + (mid.y - touchStartPoint.y);
    
    draw();
  }
}

function handleTouchEnd(e) {
  e.preventDefault();
  
  if (!isMultiTouch && !hasMovedSignificant) {
    // It's a single tap!
    if (isLocked) {
      const touch = e.changedTouches[0];
      
      // Make sure they didn't click inside the dropdown or sidebar
      if (fiDropdownContainer.classList.contains('hidden')) {
        triggerHolePopup(touch.clientX, touch.clientY);
      }
    }
  }
  
  isDraggingHole = false;
  isMultiTouch = false;
}

// Fallback Mouse Events for Desktop Testing
let isMouseDown = false;

function handleMouseDown(e) {
  // If clicking inside panels, let them handle it (although canvas is full screen, panels are on top)
  // Standard event routing handles this because panels have a higher z-index, but just in case:
  hasMovedSignificant = false;
  isMouseDown = true;
  
  touchStartPoint = { x: e.clientX, y: e.clientY };
  touchStartOffsetX = offsetX;
  touchStartOffsetY = offsetY;
  
  if (isLocked && holePlaced) {
    const cx = canvas.width / 2 + offsetX;
    const cy = canvas.height / 2 + offsetY;
    
    const hx_px = holeX_mm * scale;
    const hy_px = holeY_mm * scale;
    
    const r_hx = hx_px * Math.cos(rotation) - hy_px * Math.sin(rotation);
    const r_hy = hx_px * Math.sin(rotation) + hy_px * Math.cos(rotation);
    
    const holeScreenX = r_hx + cx;
    const holeScreenY = r_hy + cy;
    
    const dist = Math.sqrt((e.clientX - holeScreenX) ** 2 + (e.clientY - holeScreenY) ** 2);
    const radius_px = (holeDiameter_mm / 2) * scale;
    
    if (dist < Math.max(30, radius_px * 1.5)) {
      isDraggingHole = true;
      touchStartHoleX = holeX_mm;
      touchStartHoleY = holeY_mm;
    }
  }
}

function handleMouseMove(e) {
  if (!isMouseDown) return;
  
  const dx = e.clientX - touchStartPoint.x;
  const dy = e.clientY - touchStartPoint.y;
  
  if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
    hasMovedSignificant = true;
  }
  
  if (isLocked) {
    if (isDraggingHole) {
      const rx = dx * Math.cos(-rotation) - dy * Math.sin(-rotation);
      const ry = dx * Math.sin(-rotation) + dy * Math.cos(-rotation);
      
      holeX_mm = touchStartHoleX + rx / scale;
      holeY_mm = touchStartHoleY + ry / scale;
      
      updateMeasurements();
      draw();
    }
  } else {
    offsetX = touchStartOffsetX + dx;
    offsetY = touchStartOffsetY + dy;
    draw();
  }
}

function handleMouseUp(e) {
  isMouseDown = false;
  
  if (!hasMovedSignificant) {
    // Click!
    if (isLocked) {
      if (fiDropdownContainer.classList.contains('hidden')) {
        // Exclude sidebar area (right sidebar on desktop is 340px + 20px margin)
        if (window.innerWidth > 768 && e.clientX > window.innerWidth - 380) {
          return;
        }
        triggerHolePopup(e.clientX, e.clientY);
      }
    }
  }
  
  isDraggingHole = false;
}

// Utilities
function updateStatus(msg) {
  statusDisplay.innerText = msg;
}

function showToast(message) {
  // Clear any existing toasts first
  document.querySelectorAll('.hud-toast').forEach(t => t.remove());
  
  const toast = document.createElement('div');
  toast.className = 'hud-toast';
  toast.innerText = message;
  document.body.appendChild(toast);
  
  setTimeout(() => {
    toast.style.opacity = '0';
    setTimeout(() => toast.remove(), 500);
  }, 2000);
}
