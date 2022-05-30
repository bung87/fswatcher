import std / [os, tables, sets, sequtils]
import fswatcher/base

export base 

const bsdPlatform = defined(macosx) or defined(freebsd) or
                    defined(netbsd) or defined(openbsd) or
                    defined(dragonfly)
when defined(linux):
  import std/inotify
  from posix import nil
  proc fcntl(a1: cint | SocketHandle | FileHandle, a2: cint): cint {.varargs, importc, header: "<fcntl.h>", sideEffect.}

elif bsdPlatform:
  import std / [selectors]
  from posix import nil

type WatchCallback = proc (e: WatchEvent)
type FsWatcher* = ref object
  wached: TableRef[string, WatchCallback]
  fds: seq[cint]
  when defined(linux):
    inoty: FileHandle
  elif bsdPlatform:
    selector: Selector[string]

proc newFsWatcher*(): FsWatcher = 
  result = new FsWatcher
  result.wached = TableRef[string, WatchCallback]()
  when defined(linux):
    result.inoty = inotify_init()
  elif bsdPlatform:
    result.selector = newSelector[string]()

proc watch*(watcher: FsWatcher, path:string, callback: WatchCallback) =
  watcher.wached[path] = callback
  when defined(linux):
    let fd: cint = inotify_add_watch(inoty, path, IN_ALL_EVENTS)
    doAssert watchdoge >= 0
    watcher.fds.add fd
  elif bsdPlatform:
    let fd = posix.open(path, fmRead.cint)
    let evKinds = {
        Event.VnodeWrite,
        Event.VnodeDelete,
        Event.VnodeExtend,
        Event.VnodeAttrib,
        Event.VnodeLink,
        Event.VnodeRename,
        Event.VnodeRevoke
      }
    watcher.selector.registerVnode(fd, evKinds, path)
    watcher.fds.add fd


proc start*(watcher: FsWatcher) =
  when defined(linux):
    var evs = newSeq[byte](8192)
    var e: WatchEvent
    var name: string
    var origin: cstring
    while (let n = posix.read(fd, evs[0].addr, 8192); n) > 0:
      for e in inotify_events(evs[0].addr, n): 
        doAssert fcntl(e[].wd,F_GETPATH, origin ) != -1
        name = $e[].wd
        if $origin notin watcher.wached:
          continue
        case e[].mask
        of IN_MODIFY:
          e = (name, action: WatchEventKind.Modify,newName:"" )
        of IN_CREATE:
          e = (name, action: WatchEventKind.Create,newName:"" )
        of IN_DELETE:
          e = (name, action: WatchEventKind.Remove,newName:"" )
        of IN_MOVED_FROM:
          e = (name, action: WatchEventKind.Rename,newName:"" )
        of IN_MOVED_TO:
          e = (name, action: WatchEventKind.Rename,newName:"" )
        watcher.wached[origin](e)

  elif bsdPlatform:
    const yieldFilter = {pcFile,pcDir,pcLinkToFile,pcLinkToDir}
    const followFilter = {pcDir, pcLinkToDir}
    let records = TableRef[string, HashSet[string]]()
    var events: seq[ReadyKey]
    var origin: string
    var e: WatchEvent
    for k in watcher.wached.keys():
      if dirExists(k):
        records[k] = toHashSet(toSeq(walkDirRec(k, yieldFilter)))
    while true:
      events = watcher.selector.select(200)
      for ev in events:
        origin = watcher.selector.getData(ev.fd.int)
        if origin notin watcher.wached:
          continue
        if origin in records:
          let newFs = toHashSet(toSeq(walkDirRec(origin, yieldFilter)))
          let nl = newFs.len
          let ol = records[origin].len
          let diff = toSeq(symmetricDifference(records[origin],newFs))
          if diff.len > 0:
            if nl > ol:
              e = (name: diff[0],action: WatchEventKind.Create,newName:"" )
            elif ol > nl:
              e = (name: diff[0],action: WatchEventKind.Remove,newName:"" )
            else:
              var o: string
              var n: string
              for d in diff:
                if d in records[origin]:
                  o = d
                else:
                  n = d
              e = (name: o,action: WatchEventKind.Rename,newName:n )
            records[origin] =  newFs
          watcher.wached[origin](e)

proc stop*(watcher: FsWatcher) =
  when defined(linux):
    for fd in watcher.fds:
      doAssert inotify_rm_watch(watcher.inoty, watchdoge) >= 0
  elif bsdPlatform:
    for fd in watcher.fds:
      watcher.selector.unregister fd.int
