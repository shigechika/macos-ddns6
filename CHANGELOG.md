# Changelog

## 1.0.0 (2026-07-08)


### Features

* add IPv4 (A record) DDNS support ([#4](https://github.com/shigechika/macos-ddns6/issues/4)) ([0464256](https://github.com/shigechika/macos-ddns6/commit/0464256b8d05b4fbc88709818102f9c95d695e71))
* add LaunchDaemon mode for headless/server operation ([c29df72](https://github.com/shigechika/macos-ddns6/commit/c29df7256889728c19de30c01d63eb27ab770e69))
* add release-please and copilot-instructions.md ([#5](https://github.com/shigechika/macos-ddns6/issues/5)) ([c32afb8](https://github.com/shigechika/macos-ddns6/commit/c32afb847abe475db43360d8475116fc3a3fbf4e))
* auto-detect Python 3.10+ for CLOUDSDK_PYTHON in install.sh ([adee58e](https://github.com/shigechika/macos-ddns6/commit/adee58e10d7f0fa1edccb59e1a1f3cb1b6b51fd2))
* initial release of macos-ddns6 ([e83c9da](https://github.com/shigechika/macos-ddns6/commit/e83c9dae77b87258c184a9a476ba1d79d52f21c4))


### Bug Fixes

* activate service account before gcloud DNS operations ([3a21738](https://github.com/shigechika/macos-ddns6/commit/3a21738dc3e0951fde83b79ef6d1f7b15bfcf33e)), closes [#1](https://github.com/shigechika/macos-ddns6/issues/1)
* add CLOUDSDK_PYTHON to launchd plist for gcloud virtenv workaround ([9436380](https://github.com/shigechika/macos-ddns6/commit/9436380e7951f158bf1e4fd5693596917430abb8))
* LaunchDaemon gcloud project isolation and SA key path ([#3](https://github.com/shigechika/macos-ddns6/issues/3)) ([f5d9c26](https://github.com/shigechika/macos-ddns6/commit/f5d9c262d081e7e44c6518699eee5f1ec41d0365))
* use /usr/bin/python3 as default CLOUDSDK_PYTHON for portability ([202f717](https://github.com/shigechika/macos-ddns6/commit/202f7177445249c7e6d795d51a4aba7009da8299))
