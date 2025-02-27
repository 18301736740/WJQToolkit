#Copyright (C) 2018 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.



#Y5_X5_Android14_ab1 dir
sdk_root="/mnt/fileroot2/jianqun.wang/U_Android14/Y5_X5_Android14_ab1"


# 定义默认的 patch_path
patch_path="/mnt/fileroot2/jianqun.wang/zte-project-patch/U/Y5_X5_Android14_ab1/patch-list.txt"

# 检查是否有参数传递给脚本
if [ $# -eq 0 ]; then
    # 如果没有参数，则报错并退出脚本
    cd $sdk_root
    if [ $? -ne 0 ]; then
        echo "Error: Failed to change directory to $sdk_root. Please check the path."
        exit 1
    fi
    repo forall -c "git reset --hard Y5_X5_Android14_ab1_20250121"
    echo "Patch path set to: $patch_path"
elif [ $# -eq 1 ]; then
    # 如果有一个参数，则根据参数设置patch_path和执行相应的repo forall命令
    date_arg=$1
    patch_path="/mnt/fileroot2/jianqun.wang/zte-project-patch/U/Y5_X5_Android14_ab1/patch-list-${date_arg}.txt"
    echo "Patch path set to: $patch_path"
    cd $sdk_root
    if [ $? -ne 0 ]; then
        echo "Error: Failed to change directory to $sdk_root. Please check the path."
        exit 1
    fi
    # 根据日期参数选择不同的reset命令
    if [ "$date_arg" == "20241018" ]; then
        repo forall -c "git reset --hard Y5_X5_Android14_ab1_base"
    elif [ "$date_arg" == "20250110" ]; then
        repo forall -c "git reset --hard Y5_X5_Android14_ab1_20250110"
    else
        echo "Error: Unsupported date argument. Please use a valid date (e.g., 20241018 or 20250110)."
        exit 1
    fi
    cd -
elif [ $# -eq 2 ]; then
    # 如果是两个参数则为apply patch 功能
    patch_path=$1
    sdk_root=$2
else
	# 如果参数数量不正确，则报错并退出脚本
    echo "Error: Invalid number of arguments. Usage: $0 <date>"
    exit 1
fi

function usage()
{
	echo "example:"
	echo "./customer-patch/apply-patches.sh customer-patch/patches/q-unify-0208/patch-list.txt"
	echo 
	echo "customer-patch/patches/q-unify-0208/patch-list.txt -->patch list file"
	echo "customer-patch/patches/q-unify-0208/0001-210312-common-patch-0312/vendor/amlogic/common/00*.patch"
	echo "customer-patch/patches/q-unify-0208/  -->is patch root dir"
	echo "                                    0001-210312-common-patch-0312 -->is a patch package"
	echo "                                                                 vendor/amlogic/common/ -->is patch dir"
	echo 
}


function wait_for_continue()
{
	local answer=n; 
	while [ "$answer" != "c" ] ;
	do 
		read -n1 -p "press “c” to continue..." answer ;
	done
	echo
}

#apply patches in a dir
#arg1: patch_from_dir
#arg2: patch_to_dir
function apply_patch_dir()
{
	local patch_from_dir=$1
	local patch_to_dir=$2
	local patch

	if [ ! -d $patch_from_dir ]; then
		echo "patch_from_dir error:$patch_from_dir"
		exit
	fi

	if [ ! -d $patch_to_dir ]; then
		echo "patch_to_dir error:$patch_to_dir"
		exit
	fi
	cd $patch_from_dir
	for patch in `ls *.patch | sort`
	do
		echo -n "apply "`echo $patch_from_dir/$patch |sed s#$sdk_root/## `

		local change_id=`grep -m1 '^Change-Id' $patch | cut -f 2 -d " "`
		
		if [ -z $change_id ]; then
			echo "\n no Change-Id in the patch!!! we will skip it!"
			wait_for_continue
			continue
		fi

		git -C $patch_to_dir log -n 2000 | grep $change_id 1>/dev/null 2>&1;
		if [ $? -ne 0 ]; then
			git -C $patch_to_dir am --ignore-whitespace -q $patch_from_dir/$patch  1>/dev/null 2>&1
			if [ $? != 0 ]; then
				echo " FAILED!!! Need check and exit!"
				echo "git -C $patch_to_dir am -q $patch_from_dir/$patch"
				git am --skip
				exit 
			fi
			echo " SUCCESS."		
		else
			echo "aready patched. skiped!!!"
			#wait_for_continue
		fi
	done
}

#apply patche a package
#arg1: patch_package_dir
#arg2: patch_sdk_dir
function apply_patch_package()
{
	local patch_package_dir=$1
	local patch_sdk_dir=$2
	local patch_dir
	
	cd $patch_package_dir
	for patch_dir in `find -type f  -name "*.patch" |xargs dirname | sort  |uniq `
	do
		apply_patch_dir $patch_package_dir/$patch_dir   $patch_sdk_dir/$patch_dir 
	done
}

#apply patch list
#arg1: patch list file
function apply_patchs_list() 
{
	if [ ! -f $1 ]; then
		echo "patch_list_file error:$1"
		usage
		exit
	fi

	local patch_list_file=$1
	local patch_root=`dirname $1`
	local patch_package
	
	for patch_package in `cat $patch_list_file`
	do
		if [ -d $patch_root/$patch_package ] ; then 
			#echo "apply $patch_root/$patch_package"
			apply_patch_package $patch_root/$patch_package $sdk_root
		else
			echo "SKIP $patch_root/$patch_package"
			wait_for_continue
		fi
	done
}

#if [ -z $1 ]; then
#	usage
#	exit
#fi

apply_patchs_list $patch_path

