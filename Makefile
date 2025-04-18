.PHONY: all deb-ios-rootless deb-ios-rootful

ifneq ($(ONLY_TAG),)
VERSION := $(shell git describe --tags --abbrev=0 | sed 's/^v//g')
else
VERSION := $(shell git describe --tags --always | sed 's/-/|/' | sed 's/-/\./g' | sed 's/|/-/' | sed 's/\.g/\./g' | sed 's/^v//g')
endif

COMMON_OPTIONS = BUILD_DIR="build/" CODE_SIGNING_ALLOWED="NO" CODE_SIGNING_REQUIRED="NO" CODE_SIGN_IDENTITY="" -configuration $(CONFIGURATION)

ifneq ($(RELEASE),)
CONFIGURATION = Release
DEB_VERSION = $(VERSION)
else
CONFIGURATION = Debug
DEB_VERSION = $(VERSION)+debug
endif

COMMON_OPTIONS += -destination 'generic/platform=iOS'

PRODUCTS_DIR = build/$(CONFIGURATION)-iphoneos

STAGE_DIR = work-$(ARCHITECTURE)/stage
INSTALL_ROOT = $(STAGE_DIR)/$(INSTALL_PREFIX)

# TODO: maybe split each scheme into its own target?

all: deb

clean:
	xcodebuild -scheme ellekit $(COMMON_OPTIONS) clean
	xcodebuild -scheme injector $(COMMON_OPTIONS) clean
	xcodebuild -scheme launchd $(COMMON_OPTIONS) clean
	xcodebuild -scheme loader $(COMMON_OPTIONS) clean
	xcodebuild -scheme safemode-ui $(COMMON_OPTIONS) clean

build-ios:
	xcodebuild -scheme ellekit $(COMMON_OPTIONS)
	xcodebuild -scheme injector $(COMMON_OPTIONS)
	xcodebuild -scheme launchd $(COMMON_OPTIONS)
	xcodebuild -scheme loader $(COMMON_OPTIONS)
	xcodebuild -scheme safemode-ui $(COMMON_OPTIONS)

deb-ios-rootful: ARCHITECTURE = iphoneos-arm
deb-ios-rootful: INSTALL_PREFIX = 

deb-ios-rootless: ARCHITECTURE = iphoneos-arm64e
deb-ios-rootless: INSTALL_PREFIX = /var/jb

deb-ios-rootful deb-ios-rootless: build-ios
	@rm -rf work-$(ARCHITECTURE)
	@mkdir -p $(STAGE_DIR)

	@# Because BSD install does not support -D
	@mkdir -p $(INSTALL_ROOT)/usr/lib/ellekit
	@mkdir -p $(INSTALL_ROOT)/usr/libexec/ellekit

	@install -m644 $(PRODUCTS_DIR)/libellekit.dylib $(INSTALL_ROOT)/usr/lib/libellekit.dylib
	@install -m644 $(PRODUCTS_DIR)/libinjector.dylib $(INSTALL_ROOT)/usr/lib/ellekit/libinjector.dylib
	@install -m644 $(PRODUCTS_DIR)/pspawn.dylib $(INSTALL_ROOT)/usr/lib/ellekit/pspawn.dylib
	@install -m644 $(PRODUCTS_DIR)/libsafemode-ui.dylib $(INSTALL_ROOT)/usr/lib/ellekit/MobileSafety.dylib
	@install -m755 $(PRODUCTS_DIR)/loader $(INSTALL_ROOT)/usr/libexec/ellekit/loader

	@find $(INSTALL_ROOT)/usr/lib -type f -exec ldid -S {} \;
	@ldid -S./loader/taskforpid.xml $(INSTALL_ROOT)/usr/libexec/ellekit/loader
	
	@ln -s $(INSTALL_PREFIX)/usr/lib/ellekit/libinjector.dylib $(INSTALL_ROOT)/usr/lib/TweakLoader.dylib
	@ln -s $(INSTALL_PREFIX)/usr/lib/ellekit/libinjector.dylib $(INSTALL_ROOT)/usr/lib/TweakInject.dylib
	@ln -s $(INSTALL_PREFIX)/usr/lib/libellekit.dylib $(INSTALL_ROOT)/usr/lib/libsubstrate.dylib
	@ln -s $(INSTALL_PREFIX)/usr/lib/libellekit.dylib $(INSTALL_ROOT)/usr/lib/libhooker.dylib
	@ln -s $(INSTALL_PREFIX)/usr/lib/libellekit.dylib $(INSTALL_ROOT)/usr/lib/libblackjack.dylib

	@mkdir -p $(INSTALL_ROOT)/etc/rc.d
	@ln -s ${INSTALL_PREFIX}/usr/libexec/ellekit/loader $(INSTALL_ROOT)/etc/rc.d/ellekit-loader

	@mkdir -p $(INSTALL_ROOT)/usr/lib/TweakInject

	@mkdir -p $(INSTALL_ROOT)/Library/Frameworks/CydiaSubstrate.framework
	@ln -s ${INSTALL_PREFIX}/usr/lib/libellekit.dylib $(INSTALL_ROOT)/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate
	@mkdir -p $(INSTALL_ROOT)/Library/EE59E951-FDD0-C6BF-809A-C35D0599D729
	@ln -s ${INSTALL_PREFIX}/usr/lib/TweakInject $(INSTALL_ROOT)/Library/EE59E951-FDD0-C6BF-809A-C35D0599D729/AI-155D000B-3232-7A8E-BFB2-07BEF118D7A6

	@mkdir -p $(INSTALL_ROOT)/usr/share/doc/ellekit
	@install -m644 LICENSE $(INSTALL_ROOT)/usr/share/doc/ellekit/LICENSE

	@mkdir -p $(STAGE_DIR)/DEBIAN
	@sed -e "s|@DEB_VERSION@|$(DEB_VERSION)|g" -e "s|@DEB_ARCH@|$(ARCHITECTURE)|g" packaging/control >$(STAGE_DIR)/DEBIAN/control
	@sed -e "s|@DEB_VERSION@|$(DEB_VERSION)|g" -e "s|@DEB_ARCH@|$(ARCHITECTURE)|g" -e "s|@INSTALL_PREFIX@|$(INSTALL_PREFIX)|g" packaging/preinst >$(STAGE_DIR)/DEBIAN/preinst
	@sed -e "s|@DEB_VERSION@|$(DEB_VERSION)|g" -e "s|@DEB_ARCH@|$(ARCHITECTURE)|g" -e "s|@INSTALL_PREFIX@|$(INSTALL_PREFIX)|g" packaging/postinst >$(STAGE_DIR)/DEBIAN/postinst
	@sed -e "s|@DEB_VERSION@|$(DEB_VERSION)|g" -e "s|@DEB_ARCH@|$(ARCHITECTURE)|g" -e "s|@INSTALL_PREFIX@|$(INSTALL_PREFIX)|g" packaging/postrm >$(STAGE_DIR)/DEBIAN/postrm
	@chmod 0755 $(STAGE_DIR)/DEBIAN/preinst $(STAGE_DIR)/DEBIAN/postinst $(STAGE_DIR)/DEBIAN/postrm

	@mkdir -p packages
	dpkg-deb --root-owner-group -b $(STAGE_DIR) packages/ellekit_$(DEB_VERSION)_$(ARCHITECTURE).deb
	
	@rm -rf work-$(ARCHITECTURE)

deb-ios: deb-ios-rootful deb-ios-rootless
deb: deb-ios
build: build-ios
