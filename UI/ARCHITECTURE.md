# EasyTrainer UI

`UI` is the single interface namespace. Feature views depend on the public facade
from `UI/init.lua`; they do not depend on rendering internals.

## Structure

- `Render.lua` coordinates the frame and owns the ImGui window lifecycle.
- `Navigation` owns selection, scrolling, normalized input, and modal modes.
- `Option` is the new public option facade; `Options/Buttons.lua` is the compatibility
  facade used by feature views during their gradual data-driven cleanup.
- `Widgets` contains reusable option and detached-surface behavior.
- `Panels` contains the background, header, breadcrumbs, footer, tips, side panels,
  and notification presentation.
- `Registry` owns stable option identity, metadata, search, action dispatch, and
  future hotkey assignments.
- `Style` is the only source of layout, colors, and animation defaults.

## Render order

1. Begin the navigation frame
2. Draw the background, header, and breadcrumb bar
3. Draw the animated selection and current feature view
4. Draw modal surfaces such as dropdowns
5. Update scrolling and draw the footer
6. End the main window
7. Draw submitted side panels and the selected-option tip
8. Draw notifications independently so they remain visible when the menu is closed

## Conventions

- Public functions and owned state use `PascalCase`.
- Stateful systems expose `Initialize`, `Begin`, `Update`, `Draw`, and `Shutdown`
  where those lifecycle stages apply.
- Stable registry IDs never use translated labels.
- Feature modules own gameplay state and behavior.
- The registry owns identity and discovery.
- The option facade owns drawing and interaction.
- `Config/OptionConfig.lua` owns persistent option values.
- `Config/UIConfig.lua` owns the consolidated appearance schema.

## Implemented

- Single live renderer and UI namespace
- Keyboard, controller, and mouse navigation
- Animated scrolling and submenu position restoration
- Breadcrumb paths and detached information panel
- Buttons, toggles, numeric controls, radio groups, string cyclers, text input,
  color editing, bindings, and detached dropdowns
- Clean notification queue with stacking and duration progress
- Searchable, hotkey-ready option registry
- Versioned appearance configuration with legacy-value migration
