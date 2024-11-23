local styles = data.raw["gui-style"].default

styles.miex_naked_scroll_pane = {
  type = "scroll_pane_style",
  extra_padding_when_activated = 0,
  padding = 0,
}

styles.frame_action_button_red = {
  type = "button_style",
  parent = "frame_action_button",
  default_graphical_set =
  {
    base = { position = { 136, 17 }, corner_size = 8 },
    shadow = { position = { 440, 24 }, corner_size = 8, draw_type = "outer" },
  },
  hovered_graphical_set =
  {
    base = { position = { 170, 17 }, corner_size = 8 },
    shadow = { position = { 440, 24 }, corner_size = 8, draw_type = "outer" },
    glow = default_glow(red_button_glow_color, 0.5) --luacheck: ignore
  },
  clicked_graphical_set =
  {
    base = { position = { 187, 17 }, corner_size = 8 },
    shadow = { position = { 440, 24 }, corner_size = 8, draw_type = "outer" }
  },
  disabled_graphical_set =
  {
    base = { position = { 153, 17 }, corner_size = 8 },
    shadow = { position = { 440, 24 }, corner_size = 8, draw_type = "outer" }
  },
  left_click_sound = { { filename = "__core__/sound/gui-red-button.ogg", volume = 0.5 } },
}
