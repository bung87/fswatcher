type
  WatchEventKind* {.pure.} = enum
    NonAction
    Create, Modify, Rename, Remove
    CreateSelf, RemoveSelf

  WatchEvent* = tuple
    name: string
    action: WatchEventKind
    newName: string