-- Compose an X post in a floating webapp window. The window class prefix
-- follows the default browser (brave/chrome/chromium/...), so match them all.
-- Size uses Hyprland window-rule expressions (fractions of the monitor).
o.bind("CTRL + SHIFT + X", "X Post", { webapp = "https://x.com/compose/post" })
o.window("(chrome|brave|chromium|vivaldi|opera|helium|microsoft-edge)-x\\.com__compose_post.*", {
  float = true,
  size = { "monitor_w * 0.6", "monitor_h * 0.6" },
})
