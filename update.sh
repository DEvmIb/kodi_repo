_md5=$(md5sum addons.xml|cut -d' ' -f1)
echo md5: $_md5
echo $_md5 > addons.xml.md5

git commit -a -m "repo update"
git push https://$(curl -X RAW http://keyserver/gitea-user):$(curl -X RAW http://keyserver/gitea-pass)@$(curl -X RAW http://keyserver/gitea-url)
