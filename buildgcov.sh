#! /bin/sh

# Set vars for all the steps
GCB_RSYNC=1
GCB_BUILD=1
GCB_MAKE=1
GCB_TEST=1
GCB_GATHER=1
GCB_COVER=1
GCB_ARCHIVE=1
DBG_SYM=""
for argv
    do case $argv in
        -nosync)    GCB_RSYNC=0   ;;
        -nobuild)   GCB_BUILD=0   ;;
        -nomake)    GCB_MAKE=0    ;;
        -notest)    GCB_TEST=0    ;;
        -nogather)  GCB_GATHER=0  ;;
        -nocover)   GCB_COVER=0   ;;
        -noarchive) GCB_ARCHIVE=0 ;;
        -debug)     DBG_SYM="GCB_RSYNC GCB_BUILD GCB_MAKE GCB_TEST"
                    DBG_SYM="$DBG_SYM GCB_GATHER GCB_COVER GCB_ARCHIVE" ;;
        -*)         if [ "$argv" == "--help" -o "$argv" == "-h" ] ; then
                        echo ""
                    else
                        echo "Unknown argument '$argv'"
                    fi
                    cat <<EOF && exit ;;
Usage: $0 [options]
  -nosync     Don't sync the source-tree
  -nobuild    Don't call 'make perl.gcov'
  -nomake     Don't call 'make'
  -notest     Don't call 'make test'
  -nogather   Don't gather all the gcov information
  -nocover    Don't run Devel::Cover's cover
EOF
    esac
done


# Debug info
for sym in $DBG_SYM ; do
    val='$'$sym
    val=`eval echo $val`
    echo "\$$sym=$val"
done

basedir="$HOME/Test-Smoke"
builddir="$basedir/perl-current-gcov"
if [ ! -d $builddir ] ; then
    echo "Create '$builddir'"
    mkdir -p "$builddir"
fi
# set the flags needed for a gcov build
gcovflags="-fprofile-arcs -ftest-coverage"

cd $builddir

if [ "$GCB_RSYNC" == "1" ] ; then
  echo "rsync with bleadperl"
  rsync -azq --delete public.activestate.com::perl-current .
fi

logf="$basedir/gcov/buildgcov.log"
echo "gcov run for `cat $builddir/.patch`" > "$logf"
if [ "$GCB_BUILD" == "1" ] ; then
    opt=""
    sh ./Configure -des -Dusedevel $opt               \
                   -A prepend:ccflags="$gcovflags"    \
                   -A prepend:ldflags="$gcovflags"    \
                   -A prepend:lddlflags="$gcovflags -shared" \
                   -Dextras='Devel::Cover'          >> "$logf" 2>&1

# build the special binary and copy it to the default
    make perl.gcov >> "$logf" 2>&1
    cp -v perl.gcov perl
fi

# Copy a pre-cooked CPAN config to help 'Dextras='
# make will build all modules and invoke CPAN to build Devel::Cover
if [ "$GCB_MAKE" == "1" ] ; then
    cp -v "$basedir/gcov/CPAN-Config.pm" lib/CPAN/Config.pm
    make >> "$logf" 2>&1
fi

coverdir=`ls "$builddir/ext" | grep Devel-Cover`
incbase="$builddir/ext/$coverdir/blib"
usecover=-MDevel::Cover=-ignore,\\.t$,-inc,/does/not/exist
inccover="-I$incbase/lib -I$incbase/arch"

if [ "$GCB_TEST" == "1" ] ; then
    echo "test_harness with '$inccover $usecover'"
    HARNESS_PERL_SWITCHES="$inccover $usecover" \
        make test_harness >> "$logf" 2>&1
fi

# here we gather the coverage data
if [ "$GCB_GATHER" == "1" ] ; then
    cd "$builddir"
    echo "Start gathering from `pwd`"
    execindir="$basedir/gcov/exec-in-dir"

    find "$builddir" -type f -name "*.c"    -exec "$execindir" {} gcov {} \;

    PERL5LIB="$incbase/lib:$incbase/arch" \
        find "$builddir" -type f -name "*.gcov" \
             -exec ./perl -Ilib "$incbase/script/gcov2perl" \
                          -db "$builddir/t/cover_db" {} \;
fi

if [ "$GCB_COVER" == "1" ] ; then
    cd t
    PERL5LIB="$incbase/lib:$incbase/arch" \
        ../perl -I../lib $inccover "$incbase/script/cover"
fi

if [ "$GCB_ARCHIVE" == "1" ] ; then
    cd "$basedir/gcov"
    if [ -d 'perlcover' ] ; then rm -rf perlcover ; fi
    mkdir perlcover
    find "$builddir/t/cover_db/" -type f  -name "*.html" \
         -exec cp -v {} perlcover/ \;

    find "$builddir/t/cover_db/" -type f  -name "*.css" \
         -exec cp -v {} perlcover/ \;

    "$builddir/perl" "-I$builddir/lib" -V > perlcover/dashV.txt
    cp -v $logf perlcover/
    cp -v index.shtml perlcover/

    my_arch=perlcover`cat "$builddir/.patch"`.tbz
    echo "Create '$my_arch'"
    tar -cjvf "$my_arch" perlcover/

    if [ -d 'perlcover' ] ; then rm -rf perlcover ; fi
fi