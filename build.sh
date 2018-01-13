THREAD_COUNT=$(($(getconf _NPROCESSORS_ONLN)+1))
SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
WRT_DIR=$SCRIPT_DIR/../

echo "Using $THREAD_COUNT threads to build"
echo "Running in directory: $SCRIPT_DIR"

patch_sources()
{
    cd $1
    ./scripts/feeds update -a >& feeds.log
    ./scripts/feeds install -a >& feeds.log

    for i in $( ls patches ); do
        echo Applying patch $i
        patch -p1 < patches/$i
    done

    # We need to run defconfig first in case theres stuff patched
    make defconfig 
    cat config.diff >> .config
    make defconfig

    minify_sources
}

minify_sources() 
{
    directory=./feeds
    if [ ! -f compiler-latest.zip ]; then
        wget http://dl.google.com/closure-compiler/compiler-latest.zip
        unzip -qn compiler-latest.zip
    fi

    if [ ! -f yuicompressor-2.4.8.jar ]; then
        wget https://github.com/yui/yuicompressor/releases/download/v2.4.8/yuicompressor-2.4.8.jar
    fi

    for file in $( find $directory -name '*.js' )
        do
            if [[ $file == *arduino* ]] 
            then
                echo Skipping $file
                    continue
                fi
            if [[ $file == *min* ]]
            then
                echo Already minified $file
                    continue
            fi
            echo Compiling $file
            java -jar closure-compiler-*.jar --warning_level QUIET --compilation_level=SIMPLE_OPTIMIZATIONS --js="$file" --js_output_file="$file-min.js"
            mv -b "$file-min.js" "$file"
        done

    for file in $( find $directory -name '*.css' )
    do
        echo Minifying $file
        java -jar yuicompressor-2.4.8.jar -o "$file-min.css" "$file"
        mv -b "$file-min.css" "$file"
    done

    for file in $( find $directory -name '*.png' ) 
    do
        echo optipng $file
        optipng -o7 -strip all "$file" 
    done

    for file in $( find $directory -name '*.jpg' ) 
    do
        echo guetzli $file
        guetzli --quality 85 "$file" "$file.new"
        mv "$file.new" "$file"
    done

}

build_config() {
    BUILD_TARGET=$1
    cp -R fresh build/$BUILD_TARGET
    cp -R builders/$BUILD_TARGET/* build/$BUILD_TARGET/
    cp -R builders/generic/* build/$BUILD_TARGET/patches/
    patch_sources build/$BUILD_TARGET/
    make -j$THREAD_COUNT
    cd $WRT_DIR
}

echo "Removing old stuff"
rm -rf build && mkdir build
echo "Getting updates from git"
cd fresh/ && git pull --rebase
cd ..
echo "Starting UAP build."
build_config uap-ac-pro
echo "Starting USG build."
build_config usg3p
