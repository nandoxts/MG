-- ════════════════════════════════════════════════════════════════
-- THEME v8.3 — BLACK EDITION · SIN ALIASES
-- by ignxts
-- ════════════════════════════════════════════════════════════════

local THEME = {
	-- ═══ FONDOS (3 niveles + subtle) ═══
	bg       = Color3.fromRGB(5,   5,   5),    -- fondo base negro
	card     = Color3.fromRGB(14,  14,  14),   -- tarjetas, contenedores
	elevated = Color3.fromRGB(28,  28,  28),   -- hover, items activos
	subtle   = Color3.fromRGB(55,  55,  55),   -- bordes suaves, placeholders

	-- ═══ TEXTO (3 niveles) ═══
	text     = Color3.fromRGB(255, 255, 255),  -- blanco puro
	dim      = Color3.fromRGB(200, 200, 200),  -- texto suave
	muted    = Color3.fromRGB(130, 130, 130),  -- texto apagado

	-- ═══ BORDE ═══
	stroke   = Color3.fromRGB(85,  85,  85),

	-- ═══ ACENTO ═══
	accent   = Color3.fromRGB(200, 200, 200),  -- gris claro (progreso, highlights)

	-- ═══ ESTADOS ═══
	danger   = Color3.fromRGB(210, 45,  25),
	success  = Color3.fromRGB(60,  170,  85),
	warn     = Color3.fromRGB(200, 185,  50),

	-- ═══ ALPHA ═══
	overlayAlpha = 0.5,
	frameAlpha   = 0.08,
	lightAlpha   = 0.15,
	mediumAlpha  = 0.6,
	subtleAlpha  = 0.7,

	-- ═══ LAYOUT ═══
	panelWidth  = 390,
	panelHeight = 500,
}

return THEME