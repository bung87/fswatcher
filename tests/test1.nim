import std/[unittest, os]
import .. / src / fswatcher

suite "fswatcher":
  test "watch":
    let watcher = newFsWatcher()
    let temp = getTempDir()
    let cb = proc (e: WatchEvent) =
      echo e
    echo temp
    watcher.watch(temp, cb)
    watcher.start()
