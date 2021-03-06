#! /usr/bin/env bash
# Mount JuliaBox loopback volumes

if [ $# -ne 4 ]
then
    echo "Usage: sudo mount_fs.sh <data_location> <ndisks> <ds_size_mb> <fs_user_id>"
    exit 1
fi

if [ "root" != `whoami` ]
then
    echo "Must be run as superuser"
	exit 1
fi

DATA_LOC=$1
NDISKS=$2
FS_SIZE_MB=$3
ID=$4

echo "Creating and mounting $NDISKS user disks of size $FS_SIZE_MB MB each..."

function error_exit {
	echo "$1" 1>&2
	exit 1
}

FS_DIR=${DATA_LOC}/disks
LOOP_IMG_DIR=${FS_DIR}/loop/img
LOOP_MNT_DIR=${FS_DIR}/loop/mnt
echo "    Creating folders to hold filesystems..."
mkdir -p ${FS_DIR} ${LOOP_IMG_DIR} ${LOOP_MNT_DIR} || error_exit "Could not create folders to hold filesystems"

echo "Creating template disk image..."
dd if=/dev/zero of=${LOOP_MNT_DIR}/jimg bs=1M count=${FS_SIZE_MB} || error_exit "Error creating disk image file"
FREEDEV=`losetup -f`
losetup ${FREEDEV} ${LOOP_MNT_DIR}/jimg || error_exit "Error mapping template disk image"
mkfs -t ext3 -m 1 -N 144000 -v ${FREEDEV} || error_exit "Error making ext3 filesystem at ${FREEDEV}"
chown -R ${ID}:${ID} ${FREEDEV} || error_exit "Error changing file ownership on ${FREEDEV}"
losetup -d ${FREEDEV}

echo "    Creating loopback devices..."
NDISKS=$((NDISKS-1))
for i in $(seq 0 ${NDISKS})
do
    echo -n "${i}."
    LOOP=`losetup -f`
    MNT=${LOOP_MNT_DIR}/${i}
    IMG=${LOOP_IMG_DIR}/${i}

    if [ ! -e $LOOP ]
    then
        mknod -m0660 $LOOP b 7 $i || error_exit "Could not create loop device $LOOP."
        chown root.disk $LOOP || error_exit "Could not create loop device $LOOP. Error setting owner."
    fi

    if [ ! -e ${IMG} ]
    then
        cp ${LOOP_MNT_DIR}/jimg ${IMG}
    fi
    losetup ${LOOP} ${IMG} || error_exit "Error mapping ${IMG} to ${LOOP}"

    if [ ! -e ${MNT} ]
    then
        mkdir -p ${MNT} || error_exit "Error creating mount point ${MNT}"
    fi

    mount ${LOOP} ${MNT} || error_exit "Error mounting filesystem at ${MNT}"
    chown -R ${ID}:${ID} ${MNT} || error_exit "Error changing file ownership on ${MNT}"
done

rm -f ${LOOP_MNT_DIR}/jimg

echo ""
echo "DONE"
