#!/bin/bash

architecture=`uname -m`
kernelFound=0
G_KERNEL=""
G_LOCATION=""

GetDistroName()
{
	local distro_name="uknown"

	linuxString=$(grep -ihs "CentOS\|Red Hat Enterprise Linux" /etc/redhat-release)
        
	case $linuxString in
		*CentOS*)
			distro_name=CentOS
			;;
		*Red*)
			distro_name=RHEL
			;;
		*Oracle*)
			distro_name=Oracle
			;;
		*)
			distro_name=unknown
			;;
	esac
        
	echo $distro_name
	return 0
}

GetDistroVersion()
{
	local kernelVersionString=$1
	local regex='([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)'
	local distro_version="unkown"

	if [[ "${kernelVersionString}" =~ $regex  ]]; then
		kernelVersion=${BASH_REMATCH[1]}
		kernelChange=${BASH_REMATCH[2]}

		#
		# If a 5.x kernel
		#
		if [ "2.6.18" == ${kernelVersion} ]; then
			if [ ${kernelChange} -ge 412 ]; then
                                distro_version='unknown'
			elif [ ${kernelChange} -ge 411 ]; then
				distro_version='511_UPDATE'
			elif [ ${kernelChange} -ge 398 ]; then
				distro_version='511'
			elif [ ${kernelChange} -ge 371 ]; then
				distro_version='510'
			elif [ ${kernelChange} -ge 348 ]; then
				distro_version='59'
			elif [ ${kernelChange} -ge 308 ]; then
				distro_version='58'
			elif [ ${kernelChange} -ge 274 ]; then
				distro_version='57'
			elif [ ${kernelChange} -ge 238 ]; then
				distro_version='56'
			elif [ ${kernelChange} -ge 194 ]; then
				distro_version='55'
			elif [ ${kernelChange} -ge 164 ]; then
				distro_version='54'
			elif [ ${kernelChange} -ge 128 ]; then
				distro_version='53'
			elif [ ${kernelChange} -ge 92 ]; then
				distro_version='52'
			else
				echo "Error: Unknown 5.x kernel change: '${kernelChange}'"
			fi
		#
		# If a 6.x kernel
		#
		elif [ "2.6.32" == ${kernelVersion} ]; then
			if [ ${kernelChange} -ge 643 ]; then
                                distro_version='unknown'
			elif [ ${kernelChange} -ge 642 ]; then
				distro_version='68'
			elif [ ${kernelChange} -ge 573 ]; then
				distro_version='67'
			elif [ ${kernelChange} -ge 504 ]; then
				distro_version='66'
			elif [ ${kernelChange} -ge 431 ]; then
				distro_version='65'
			elif [ ${kernelChange} -ge 358 ]; then
				distro_version='64'
			elif [ ${kernelChange} -ge 279 ]; then
				distro_version='63'
			elif [ ${kernelChange} -ge 220 ]; then
				distro_version='62'
			elif [ ${kernelChange} -ge 131 ]; then
				distro_version='61'
			elif [ ${kernelChange} -ge 71 ]; then
				distro_version='60'
			else
				echo "Error: Unknown 6.x kernel change:  '${kernelChange}'"
			fi
		#
		# If a 7.x kernel
		#
		elif [ "3.10.0" == ${kernelVersion} ]; then
			if [ ${kernelChange} -ge 515 ]; then
                                distro_version='unknown'
			elif [ ${kernelChange} -ge 514 ]; then
				distro_version='73'
			elif [ ${kernelChange} -ge 324 ]; then
				distro_version='72'
			elif [ ${kernelChange} -ge 229 ]; then
				distro_version='71'
			elif [ ${kernelChange} -ge 123 ]; then
                                distro_version='70'
			else
				echo "Error: Unknown 7.x kernel change: '${kernelChange}'"
			fi
		else
			# Not a 2.6.18, 2.6.32, or 3.10.0 kernel - unsupported kernel version
			echo "Error: Unknown kernel version: '${kernelVersion}'"
		fi
	fi
	
	echo $distro_version	
	return 0

}

#
# Function to extract package and place files under modules for specified kernel
#
function getAndExtractKmodRpmForKernel() {
	local distro_name="unknown"
	local distro_version="unknown"
	local folder_name
	local folder_postfix="/"
	local kmodrpm=""
	local kmodrpmname=""
	local current_dir=""

	kernel=$1

	echo Get and Extract Kmod RPM for kernel $kernel

	distro_name=$(GetDistroName)
	distro_version=$(GetDistroVersion $kernel)

	if [ $distro_name == "unknown" ] || [ $distro_version == "unknown" ]; then
		echo Could not determine folder name with installation RPMs, aborting...
		exit 1
	fi 

	folder_name=$distro_name$distro_version

	if [ $distro_version == '73' ]; then
	{
		regex='3.10.0-514.10+\.[0-9]+'
		regex1='3.10.0-514.16.1'
		if [[ "$kernel" =~ $regex ]]; then
			folder_postfix=$folder_postfix"update/"
		elif [[ "$kernel" =~ $regex1 ]]; then 
			folder_postfix=$folder_postfix"update1/"
		fi
	}
	elif [ $distro_version == '64' ]; then
	{
		regex='2.6.32-358.[0-9]+\.[0-9]+'
		if [[ "$kernel" =~ $regex ]]; then
			folder_postfix=$folder_postfix"update/"
		fi
	}
	fi

	folder_name=$G_LOCATION$distro_name$distro_version$folder_postfix
	echo Folder with RPM is $folder_name

	echo "Looking for RPMs"
	find_command="find $folder_name -type f -path \""$folder_name"kmod-microsoft-hyper-v-4.2.0*x86_64.rpm\" -print"
	echo "Find command: "$find_command

	kmodrpm=`eval $find_command`
	if [ -z $kmodrpm ]; then
		echo "Could not find RPM file, exiting"
		return 1
	fi

	kmodrpmname="$(basename "$kmodrpm")"
	# Create temp directory
	temp_dir=`mktemp -d`

	if [[ ! "$temp_dir" || ! -d "$temp_dir" ]]; then
		echo "Could not create temporary directory" 
		exit 1
	else 
		echo "Temporary directory "$temp_dir" created"
	fi

	# Copy file to temporary directory
	echo "Copy files to temporary directory"
	echo cp -v $kmodrpm $temp_dir"/"$kmodrpmname
	cp -v $kmodrpm $temp_dir"/"$kmodrpmname
	
	# Save current working directory
	current_dir=`pwd`

	# Change to temp folder and extract files
	cd $temp_dir
	rpm2cpio $kmodrpmname | cpio -idmv
	rm -rf $kmodrpmname

	for file in `find -type f -print | grep -v '\.ko$|\.conf$'`
	do
		dest=`echo $file | cut -c 2-`;
		echo /bin/cp -TRv $file $dest
		mkdir -p -- "$(dirname -- "$dest")" && /bin/cp -TRv $file $dest
	done;

	cd $current_dir
	rm -rf $temp_dir
}


function getAndExtractKmodRpm {
	echo ===== Entering fixPostInstallation =====	
	local kernel

	if [ -z $G_KERNEL ]; then
		for kernel in `rpm -q kernel | cut -c 8-`
		do
			getAndExtractKmodRpmForKernel $kernel
		done
	else
		getAndExtractKmodRpmForKernel $G_KERNEL
	fi

	echo ===== Leaving fixPostInstallation =====
}

#
# Function to fix the issue introduced by post-installation script for a specific kernel
#
function fixPostInstallationForKernel() {
        local kernel=$1
	
	echo ===== Fixing PostInstallation issue for $kernel =====
	local regex='([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)'

        local libPath=("/lib/modules/"$kernel)
	local extraPath=$libPath"/extra/microsoft-hyper-v"
	local different=0
	local kernelFolder=""

	if [ ! -d "$extraPath" ]; then
		if [[ "${kernel}" =~ $regex  ]]; then
			kernelVersion=${BASH_REMATCH[0]}
		        for path in `find /lib/modules -maxdepth 1 -type d -path "*$kernelVersion*"`
			do
				extraPath=$path"/extra/microsoft-hyper-v"
				if [ -d "$extraPath" ]; then
					echo using path $extraPath
					different=1
					kernelFolder=`echo $(basename $path)`
					break
				fi
			done
		fi
	fi

	if [ -d "$extraPath" ]; then
		echo Directory $extraPath exists
		for file in `find $extraPath | grep '\.ko$'`
		do
			weakFile=${file/\/extra\//\/weak-updates\/}
			if [ $different -eq 1 ]; then
				echo using different kernel
				weakFile=${weakFile/$kernelFolder/$kernel}
			fi
			
			echo ln -sf $file $weakFile
			mkdir -p -- "$(dirname -- "$weakFile")" && ln -sf $file $weakFile
		done

		echo /sbin/depmod -ae -F /boot/System.map-$kernel $kernel
		/sbin/depmod -ae -F /boot/System.map-$kernel $kernel

		# Rebuilt initramfs image
		# dracut -f  /boot/initramfs-3.10.0-514.10.2.el7.x86_64.img 3.10.0-514.10.2.el7.x86_64
		initramfsFile="/boot/initramfs-"$kernel".img"
		if [ -f "$initramfsFile" ]; then
			cp $initramfsFile $initramfsFile"-script"
			echo InitRamFS Image $initramfsFile exists, rebuild it
			echo dracut -f $initramfsFile $kernel
			dracut -f $initramfsFile $kernel
		fi
	fi

}


#
# Function to fix the issue introdcuted by post-installation script
#
function fixPostInstallation {
	echo ===== Entering fixPostInstallation =====	
	local kernel
	
	if [ -z $G_KERNEL ]; then
		for kernel in `rpm -q kernel | cut -c 8-`
		do
			fixPostInstallationForKernel $kernel
		done
	else 
		fixPostInstallationForKernel $G_KERNEL
	fi

	echo ===== Leaving fixPostInstallation =====
}

if [ "$architecture" != "x86_64" ]; then
	echo This script support only x86_64 platform, aborting
	exit 1
fi

while getopts l:k: option
do
	case "${option}" in
		l) G_LOCATION=${OPTARG};;
		k) G_KERNEL=${OPTARG};;
	esac
done

echo $G_KERNEL - $G_LOCATION

if [ -z $G_LOCATION ]; then
	echo "You must specify LIS folder location, e.g."
	echo "	$0 -l /root/LIS-4.2.0"
	exit 1
fi

if [ ! -z $G_KERNEL ]; then
	echo "Test if supplied kernel can be accepted"
	for kernel in `rpm -q kernel | cut -c 8-`
	do
		if [ "$G_KERNEL" = "$kernel" ]; then
			kernelFound=1
			break
		fi
	done
else
	kernelFound=1
fi

if [ $kernelFound = 0 ]; then
	echo "We could not find suitable kernel to run this script, aborting"
	exit 1
fi

getAndExtractKmodRpm
fixPostInstallation
