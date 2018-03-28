#!/bin/sh

NCPU=4
ARCH_LIST="armeabi x86 mips"

[ -d openssl ] || {
	mkdir -p openssl
	git clone https://android.googlesource.com/platform/external/openssl openssl/jni -b kitkat-mr2.2-release || exit 1
	#sed -i 's/BUILD_HOST_SHARED_LIBRARY/BUILD_SHARED_LIBRARY/g' openssl/jni/*.mk
	#sed -i 's/BUILD_HOST_STATIC_LIBRARY/BUILD_STATIC_LIBRARY/g' openssl/jni/*.mk
	sed -i 's@external/openssl/@jni/@g' openssl/jni/*.mk
	echo > openssl/jni/Apps.mk
	echo APP_MODULES := libcrypto_static libssl_static > openssl/jni/Application.mk
	echo APP_ABI := $ARCH_LIST >> openssl/jni/Application.mk
	ndk-build -j$NCPU -C openssl BUILD_HOST_SHARED_LIBRARY=jni/Apps.mk BUILD_HOST_STATIC_LIBRARY=jni/Apps.mk || exit 1
	for ARCH in $ARCH_LIST; do
		mkdir -p openssl/$ARCH/lib
		ln -s -f ../jni/include openssl/$ARCH/include
		cp -f openssl/obj/local/$ARCH/libcrypto_static.a openssl/$ARCH/lib/libcrypto.a || exit 1
		cp -f openssl/obj/local/$ARCH/libssl_static.a openssl/$ARCH/lib/libssl.a || exit 1
	done
}

[ -e ../configure ] || {
	D="`pwd`"
	cd ..
	./bootstrap || exit 1
	cd "$D"
}

for ARCH in $ARCH_LIST; do

	case $ARCH in
		x86) TOOLCHAIN=i686-linux-android;;
		mips) TOOLCHAIN=mipsel-linux-android;;
		*) TOOLCHAIN=arm-linux-androideabi;;
	esac

	mkdir -p $ARCH
	cd $ARCH
	export LDFLAGS=-pie
	[ -e Makefile ] || {
		../setCrossEnvironment-$ARCH.sh ../../configure --host=$TOOLCHAIN --with-ssl=openssl --with-libssl-prefix=`pwd`/../openssl/$ARCH --disable-nls --disable-iri || exit 1
	} || exit 1

	make -j$NCPU || exit 1
	cp -f src/wget .
	../setCrossEnvironment-$ARCH.sh sh -c '$STRIP --strip-unneeded wget' || exit 1
	cd ..

done
