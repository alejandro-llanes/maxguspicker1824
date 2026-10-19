.PHONY: all build app install run test clean

all: app

build:
	swift build

app:
	./scripts/bundle_app.sh release

install: app
	pkill -f "maxguspicker1824.app" || true
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$(PWD)/build/maxguspicker1824.app" || true
	rm -rf /Applications/maxguspicker1824.app
	cp -R build/maxguspicker1824.app /Applications/maxguspicker1824.app
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/maxguspicker1824.app || true
	open /Applications/maxguspicker1824.app

run: app
	open build/maxguspicker1824.app

test:
	swift test --enable-swift-testing --disable-xctest -Xswiftc -load-plugin-library -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib

clean:
	swift package clean
	rm -rf build
