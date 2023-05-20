# oreore-mdm

## memo

### Google ログイン

誰でもできる。

### サインアップ

エンジニアによる手作業で行う。

まず Android Management API 側で Enterprise を作り

```
# export SERVICE_ACCOUNT_CREDENTIAL_JSON=$(cat ~/Downloads/oreore-mdm-*.json | base64)
# bin/console
[1] pry(main)> AndroidManagementApi.call 'POST /enterprises project_id={project_id} agreementAccepted=true', payload: { enterpriseDisplayName: 'いわきゆうすけInc' }
=> {"name"=>"enterprises/LC01abcdefg", "enterpriseDisplayName"=>"いわきゆうすけInc"}
```

ある Google アカウントのユーザがどの組織を管理できるか、の内容は `ADMIN_USERS` 環境変数に保持する。

```
export ADMIN_USERS=uid1:LC01abcdefg,BBBBNNNN;uid2:LC01abcdefg,CCCCYYYY
```
