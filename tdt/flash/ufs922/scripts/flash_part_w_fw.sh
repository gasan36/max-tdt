#!/bin/bash

CURDIR=$1
TUFSBOXDIR=$2
OUTDIR=$3
TMPKERNELDIR=$4
TMPROOTDIR=$5
TMPVARDIR=$6

echo "CURDIR       = $CURDIR"
echo "TUFSBOXDIR   = $TUFSBOXDIR"
echo "OUTDIR       = $OUTDIR"
echo "TMPKERNELDIR = $TMPKERNELDIR"
echo "TMPROOTDIR   = $TMPROOTDIR"
echo "TMPVARDIR    = $TMPVARDIR"

MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
MKSQUASHFS=$CURDIR/../common/mksquashfs4.0
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
PAD=$CURDIR/../common/pad

OUTFILE=$OUTDIR/update_w_fw.img

if [ ! -e $OUTDIR ]; then
  mkdir $OUTDIR
fi

if [ -e $OUTFILE ]; then
  rm -f $OUTFILE
fi

# --- KERNEL ---
# Size 0x1a0000
cp $TMPKERNELDIR/uImage $CURDIR/uImage
$PAD 0x1a0000 $CURDIR/uImage $CURDIR/mtd_kernel.pad.bin

# --- ROOT ---
# Create a squashfs partition for root
# Size 0xa20000
echo "MKSQUASHFS $TMPROOTDIR $CURDIR/mtd_root.bin -comp lzma -all-root"
$MKSQUASHFS $TMPROOTDIR $CURDIR/mtd_root.bin -comp lzma -b 256k -all-root
echo "PAD 0xa20000 $CURDIR/mtd_root.bin $CURDIR/mtd_root.pad.bin"
$PAD 0xa20000 $CURDIR/mtd_root.bin $CURDIR/mtd_root.pad.bin

# --- VAR ---
# Size 0x400000
echo "MKFSJFFS2 -qUfv -p0x4100000 -e0x10000 -r $TMPVARDIR -o $CURDIR/mtd_var.bin"
$MKFSJFFS2 -qUfv -p0x400000 -e0x10000 -r $TMPVARDIR -o $CURDIR/mtd_var.bin > /dev/null
echo "SUMTOOL -v -p -e 0x10000 -i $CURDIR/mtd_var.bin -o $CURDIR/mtd_var.sum.bin"
$SUMTOOL -v -p -e 0x10000 -i $CURDIR/mtd_var.bin -o $CURDIR/mtd_var.sum.bin > /dev/null
echo "$PAD 0x410000 $CURDIR/mtd_var.sum.bin $CURDIR/mtd_var.sum.pad.bin"
$PAD 0x400000 $CURDIR/mtd_var.sum.bin $CURDIR/mtd_var.sum.pad.bin > /dev/null

# --- update.img ---
#Merge all 3 together
cat $CURDIR/mtd_kernel.pad.bin >> $OUTFILE
cat $CURDIR/mtd_root.pad.bin >> $OUTFILE
cat $CURDIR/mtd_var.sum.pad.bin >> $OUTFILE

rm -f $CURDIR/uImage
rm -f $CURDIR/mtd_root.bin
rm -f $CURDIR/mtd_var.bin
rm -f $CURDIR/mtd_var.sum.bin

SIZE=`stat mtd_kernel.pad.bin -t --format %s`
SIZE=`printf "0x%x" $SIZE`
if [[ $SIZE > "0x1a0000" ]]; then
  echo "KERNEL TO BIG. $SIZE instead of 0x1a0000" > /dev/stderr
fi

SIZE=`stat mtd_root.pad.bin -t --format %s`
SIZE=`printf "0x%x" $SIZE`
if [[ $SIZE > "0xa20000" ]]; then
  echo "ROOT TO BIG. $SIZE instead of 0xa20000" > /dev/stderr
fi

SIZE=`stat mtd_var.sum.pad.bin -t --format %s`
SIZE=`printf "0x%x" $SIZE`
if [[ $SIZE > "0x400000" ]]; then
  echo "VAR TO BIG. $SIZE instead of 0x400000" > /dev/stderr
fi

rm -f $CURDIR/mtd_kernel.pad.bin
rm -f $CURDIR/mtd_root.pad.bin
rm -f $CURDIR/mtd_var.sum.pad.bin

zip $OUTFILE.zip $OUTFILE