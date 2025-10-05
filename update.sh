_bins=(zip git date)
_packs=(zip git)
if ! hash ${_bins[@]} &> /dev/null
then
    apt -y install ${_packs[@]} 2>/dev/null
    apk add --no-cache ${_packs[@]} 2>/dev/null
fi

if ! hash ${_bins[@]} &> /dev/null
then
    echo missing bins
    exit 1
fi

mkdir -p files

_gitea_user=$(curl -s -X RAW http://keyserver.bunker.home/gitea-user)
_gitea_pass=$(curl -s -X RAW http://keyserver.bunker.home/gitea-pass)
_gitea_url=$(curl -s -X RAW http://keyserver.bunker.home/gitea-url)

function _from_git {
    local _tmp _version
    >&2 echo processing $1 $2 $3 $4
    _tmp=$(date +%s%N)
    if [ "$_tmp" == "" ]; then >&2 echo _tmp is empty; return; fi
    mkdir -p have
    mkdir -p files
    if [ "$4" == "" ]
    then
        _last=$(git ls-remote https://$1/$2/$3|head -n1|cut -f1)
    else
        _last=$(git ls-remote https://$1/$2/$3 refs/heads/$4|head -n1|cut -f1)
    fi
    if [ "$_last" == "" ]; then >&2 echo git error. last checkout is empty.; return; fi
    if [ -e "have/$_last" ]
    then
        >&2 echo using latest
        cat have/$_last >> addons.xml
        return
    fi
    
    mkdir -p $_tmp
    git clone https://$1/$2/$3 $_tmp/$3 &>/dev/null
    if [ $? -ne 0 ]; then >&2 echo git error; rm -rf $_tmp; return; fi
    if [ ! "$4" == "" ]
    then
        echo "checkout $3 -> $4"
        (cd $_tmp/$3; git checkout $4)
        if [ $? -ne 0 ]; then >&2 echo git error; rm -rf $_tmp; return; fi
    fi
    rm -rf $_tmp/$3/.[^.]*
    if [ "$5" == "" ]
    then
        _m=1
        _version=$(tail -n +2 $_tmp/$3/addon.xml|grep version|head -n1|sed -n 's#.*version="\(.*\)".*#\1#p'|cut -d'"' -f1)
    else
        _m=2
        _version_old=$(tail -n +2 $_tmp/$3/addon.xml|grep version|head -n1|sed -n 's#.*version="\(.*\)".*#\1#p'|cut -d'"' -f1)
        echo $_version_old
        _version_date=$(cd "$_tmp/$3"; git reflog --date=local "$5"|head -n1|cut -d'{' -f2|cut -d'}' -f1)
        _version_date=$(date -d "$_version_date" +%s)
        _version=$(cd "$_tmp/$3"; git reflog --date=local "$5"|head -n1|cut -d' ' -f1)
        _version="$_version_date.$_version~git"
    fi
    if [ "$_version" == "" ]; then >&2 echo error addon version is empty; rm -rf $_tmp; return; fi
    mkdir -p files/$3
    (cd $_tmp; zip -r -9 ../files/$3/$3-$_version.zip $3 1>/dev/null)
    if [ $? -ne 0 ]; then >&2 echo zipping failed.; rm -f files/$3/$3-$_version.zip; rm -rf $_tmp; return; fi
    zip -T files/$3/$3-$_version.zip 1>/dev/null
    if [ $? -ne 0 ]; then >&2 echo testing zip failed.; rm -f files/$3/$3-$_version.zip; rm -rf $_tmp; return; fi
    tail -n +2 $_tmp/$3/addon.xml > have/$_last
    sed -i 's#version="'$_version_old'"#version="'$_version'"#g' have/$_last
    rm -rf $_tmp
    git add have/$_last
    git add files/$3/$3-$_version.zip
    cat have/$_last >> addons.xml
    >&2 echo finished
}

#header
cat << EOF > addons.xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<addons>
EOF

_from_git $_gitea_url $_gitea_user service.takealug.epg-grabber
_from_git $_gitea_url $_gitea_user service.takealug.epg-grabber 1.1.9
_from_git github.com sunsettrack4 script.service.easyepg-lite "" "main"

# myself
tail -n +2 addon.xml >> addons.xml


#end
cat << EOF >> addons.xml
</addons>
EOF


_md5=$(md5sum addons.xml|cut -d' ' -f1)
echo md5: $_md5
echo $_md5 > addons.xml.md5

sed -i 'name="DEvmIb Repository" version="\(.*\)"#name="DEvmIb Repository" version="1.'$(date +%s)'"#g' addon.xml

git config pull.rebase false &>/dev/null
git commit -a -m "repo update" 1> /dev/null
git push https://$_gitea_user:$_gitea_pass@$_gitea_url/$_gitea_user/kodi_repo 1> /dev/null
git pull 1> /dev/null

exit 0