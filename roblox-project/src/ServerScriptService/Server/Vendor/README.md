# Vendor

Módulos de terceros revisados a mano. No uses `require(id)` remotos.

## ProfileStore

- Origen: [MadStudioRoblox/ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) (loleris)
- Commit vendorizado: `45c9847cbcf1fc260369c50eb335aba7c35aecdd`
- Archivo: `ProfileStore.luau` (sin editar, para no desviarse del session lock)
- Docs: https://madstudioroblox.github.io/ProfileStore/

`DataService` lo usa con `StartSessionAsync` (sin `Steal`), `EndSession` al salir y `SetConstant("AUTO_SAVE_PERIOD", ...)`. En Studio, si `Workspace.UseLiveProfiles` no es `true`, se usa `ProfileStore.Mock`.
