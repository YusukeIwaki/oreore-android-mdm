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

その結果をローカルの Enterprise に。AdminUser で GoogleAccount と紐付け。

```
[1] pry(main)> admin_google_account = GoogleAccount.find_by(email: .....)
[2] pry(main)> enterprise = Enterprise.create!(name: 'LC01abcdefg', display_name: 'いわきゆうすけInc')
[3] pry(main)> AdminUser.create!(google_account: admin_google_account, enterprise: enterprise)
```
