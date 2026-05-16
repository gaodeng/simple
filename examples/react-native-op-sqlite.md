# React Native op-sqlite usage

This note shows how to load `simple` as a SQLite runtime extension in a React
Native app using [`@op-engineering/op-sqlite`](https://github.com/OP-Engineering/op-sqlite).

`simple` is an FTS5 tokenizer extension, so op-sqlite must be built with FTS5
enabled and with runtime extension loading available.

## Build the extension

Build an iOS xcframework:

```sh
./build-ios-dynamic.sh
```

The output is:

```text
output/libsimple-dynamic.xcframework
```

For Android, use the shared library from the normal Android build/release
artifact and package it as `libsimple.so` for each target ABI.

## iOS

Add the xcframework to your app, for example:

```text
ios/Frameworks/simple.xcframework
```

If you use CocoaPods, create a small local podspec:

```ruby
Pod::Spec.new do |s|
  s.name = 'SimpleSQLiteExtension'
  s.version = '0.1.0'
  s.summary = 'SQLite simple tokenizer extension'
  s.homepage = 'https://github.com/wangfenjin/simple'
  s.license = { :type => 'MIT' }
  s.author = { 'simple contributors' => 'https://github.com/wangfenjin/simple' }
  s.source = { :git => 'https://github.com/wangfenjin/simple.git', :tag => s.version.to_s }
  s.platform = :ios, '12.0'
  s.vendored_frameworks = 'Frameworks/simple.xcframework'
end
```

Then reference it from `ios/Podfile`:

```ruby
target 'YourApp' do
  pod 'SimpleSQLiteExtension', :path => '.'
end
```

Run:

```sh
cd ios
pod install
```

## Android

Package `libsimple.so` in your React Native project, for example:

```text
android/app/src/main/jniLibs/arm64-v8a/libsimple.so
android/app/src/main/jniLibs/armeabi-v7a/libsimple.so
android/app/src/main/jniLibs/x86/libsimple.so
android/app/src/main/jniLibs/x86_64/libsimple.so
```

## Load the extension

Load the extension before creating FTS5 tables that use the `simple` tokenizer.

```ts
import { Platform } from 'react-native';
import { getDylibPath, open } from '@op-engineering/op-sqlite';

const db = open({ name: 'search.db' });

if (Platform.OS === 'android') {
  db.loadExtension('libsimple', 'sqlite3_simple_init');
} else if (Platform.OS === 'ios') {
  const path = getDylibPath('com.wangfenjin.simple', 'simple');
  db.loadExtension(path, 'sqlite3_simple_init');
}
```

After loading succeeds, `simple` can be used like any other FTS5 tokenizer:

```ts
db.execute(`
  CREATE VIRTUAL TABLE IF NOT EXISTS docs
  USING fts5(title, body, tokenize = 'simple');
`);

db.execute('INSERT INTO docs(title, body) VALUES (?, ?)', [
  '中华人民共和国国歌',
  '支持中文和拼音搜索',
]);

const result = db.execute(
  'SELECT rowid, title FROM docs WHERE docs MATCH simple_query(?)',
  ['中华国歌'],
);
```

To disable pinyin tokens, use the tokenizer option supported by `simple`:

```ts
db.execute(`
  CREATE VIRTUAL TABLE IF NOT EXISTS docs_no_pinyin
  USING fts5(title, body, tokenize = 'simple 0');
`);
```

## Troubleshooting

- `no such tokenizer: simple` usually means the extension was not loaded before
  the FTS5 table was created.
- `not authorized` or `load extension` errors usually mean runtime extension
  loading is disabled in the SQLite build used by your app.
- iOS apps should load the framework from the app bundle. With op-sqlite, use
  `getDylibPath('com.wangfenjin.simple', 'simple')` for the framework named
  `simple.framework`.
- Android should load the library name without the `.so` suffix:
  `db.loadExtension('libsimple', 'sqlite3_simple_init')`.
