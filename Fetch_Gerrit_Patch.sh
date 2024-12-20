#!/bin/bash

if [ $# -lt 2 ]
then
    echo "Params num error."
    echo "param 1: xmlpath"
    echo "param 2: xmlsName,Separated by ; "
    echo "param 3: patchfile,  format: patchid server  (please set manifest patch ahead)"
    echo "param 4: workspace/source path "
    echo "param 5: repo_manifest file"
    exit 1
fi

patchid=$1

server=$2

date_path=$(date "+%Y-%m-%d")

#Amlogic tool path
apply_script=/mnt/fileroot2/jianqun.wang/Amlogic_tool/Apply_Patches.sh

#U source path 
u_source_path="/mnt/fileroot2/jianqun.wang/U_Android14/U_openlinux_ott_default"

#U target path
u_ab1_target_path="/mnt/fileroot2/jianqun.wang/U_Android14/Y5_X5_Android14_ab1"
u_ab2_target_path="/mnt/fileroot2/jianqun.wang/U_Android14/X4_Y4_Android14_ab2"

# Check if the current directory is one of the target paths
if [[ "$PWD" == "$u_ab1_target_path" ]]; then
    git_root_path="$u_ab1_target_path"
elif [[ "$PWD" == "$u_ab2_target_path" ]]; then
    git_root_path="$u_ab2_target_path"
else
    # If not, get the top-level directory of the current Git repository
    git_root_path=$(git rev-parse --show-toplevel)
fi

function fetch_gerrit_patch()
{
    if [ $# -lt 2 ]; then echo " fetch_gerrit_patch func need commit id and server as params!!!"; exit 1; fi
    commit=$1
    server_name=$2
	target_patch_path=$3
    DOWNLOAD_METHOD=$4
    cur_path=`pwd`

    if [[ $server_name == "scgit.amlogic.com" || $server_name == "aml-code-master.amlogic.com" ]];then
    portnumber=29418    #The port number of these two addresses is 29418:scgit.amlogic.com and aml-code-master.amlogic.com
    else
    portnumber=9000     #The port number of this address is 9000:fae-local.amlogic.com
    fi

    echo "portnumber:"$portnumber
    changeID=$(ssh -p $portnumber $server_name gerrit query --current-patch-set $commit < /dev/null | grep ' Change-Id:' | awk '{print $2}')
    echo "changeID:"$changeID
    project=$(ssh -p $portnumber $server_name gerrit query $commit < /dev/null | grep ' project:' | sed 's/.*project:\s*\(\S*\).*/\1/g' | sed 's/^acos\///')
    echo "project:"$project
    branch=$(ssh -p $portnumber $server_name gerrit query --current-patch-set $commit < /dev/null | grep ' branch:' | awk '{print $2}')
    echo "branch:"$branch

#don't fetch the patch which change the manifests dir

    if [[ "${project}" == "ap22a3/device/xiaomi" ]]; then
        #path=device/xiaomi
        path=${project#*/}
        echo "path:"$path

        echo "h [$commit] [${path}] [${project}]"
        cd $path
        git log -n 100 | grep $changeID 1>/dev/null 2>&1;
        if [ $? -ne 0 ]; then
            refID=$(ssh -p $portnumber $server_name gerrit query --current-patch-set $commit < /dev/null | grep ' ref:' | awk '{print $2}')
            if [ "$DOWNLOAD_METHOD" == "pull" ]; then
                git pull ssh://$server_name:$portnumber/$project $refID
                if [ $? != 0 ]; then
                    echo "pull the patch $commit error, please fix it."
                    cd $cur_path
                    exit 1
                fi
            else
                echo "git fetch ssh://$server_name:$portnumber/$project $refID && git cherry-pick FETCH_HEAD"
                git fetch ssh://$server_name:$portnumber/$project $refID && git cherry-pick FETCH_HEAD
                if [ $? != 0 ]; then
                    git am --abort
                    git cherry-pick --abort
                    echo "auto cherry-pick $commit error, please fix it."
                    echo "----------------------------------------------------"
                    cd $cur_path
                    exit 1
                fi
            fi
            echo "----------------------------------------------------"
        else
            echo "The gerrit id [$commit] was already merged in [$path]"
            echo "----------------------------------------------------"
        fi
        cd $cur_path

    elif [ "${project}" != "platform/manifest" -a "${project}" != "ref-o/platform/manifest" ]; then
        projectxmlname=${project//ref-o\//}
        projectxmlname=${projectxmlname//pdk-o\//}
        projectxmlname=${projectxmlname//platform\//}

        path=""

        if [[ "$projectxmlname" =~ "vendor/amlogic/tdk" && "$branch" =~ "v3" ]];then
                        path="vendor/amlogic/common/tdk_v3/"
                fi

        #echo "[$commit] [${path}]"

        if [ -z "${path}" ];then
            path=$(repo info $project | grep "Mount path" | cut -f 2 -d: | sed -e 's/^[ \t]*//')
        #echo "h [$commit] [${path}] [${project}]"
        fi
        echo "h [$commit] [${path}] [${project}]"
        echo "path:"$path
		relative_path=${path#$u_source_path/} 
        cd $path
        if [ $? != 0 ]; then
            echo "We can not find the directory: ${cur_path}/${path}"
            exit 1
        fi
        git log -n 100 | grep $changeID 1>/dev/null 2>&1;
        if [ $? -ne 0 ]; then
            refID=$(ssh -p $portnumber $server_name gerrit query --current-patch-set $commit < /dev/null | grep ' ref:' | awk '{print $2}')
            echo "git fetch ssh://$server_name:$portnumber/$project $refID && git cherry-pick FETCH_HEAD"
			mkdir -p $target_patch_path/$date_path/$relative_path
            # 检查 patch-list.txt 中是否已经有 $date_path 内容
            if ! grep -q "$date_path" "$target_patch_path/patch-list.txt"; then
                echo "$date_path" >> "$target_patch_path/patch-list.txt"
            else
                echo "Issue path $date_path already exists in $target_patch_path/patch-list.txt"
            fi            
            git fetch ssh://$server_name:$portnumber/$project $refID && git format-patch -1 FETCH_HEAD -o $target_patch_path/$date_path/$relative_path
            if [ $? != 0 ]; then
                git am --abort
                git cherry-pick --abort
                echo "auto cherry-pick $commit error, please fix it."
                echo "----------------------------------------------------"
                cd $cur_path
                exit 1
            fi
			bash $apply_script $target_patch_path/patch-list.txt  ${target_patch_path%/Target_Patch}
        else
            echo "The gerrit id [$commit] was already merged in [$path]"
            echo "----------------------------------------------------"
        fi
    fi
    cd $cur_path
}

# 生成patch
if [[ $git_root_path == $u_ab1_target_path* ]]; then
    cd $u_source_path
    mkdir -p $u_ab1_target_path/Target_Patch
    fetch_gerrit_patch $patchid $server $u_ab1_target_path/Target_Patch
elif [[ $git_root_path == $u_ab2_target_path* ]]; then
    cd $u_source_path
    mkdir -p $u_ab2_target_path/Target_Patch
    fetch_gerrit_patch $patchid $server $u_ab2_target_path/Target_Patch
else
    echo "当前 Git 仓库不位于指定的 repo 根目录下。"
fi
