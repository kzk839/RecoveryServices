# RecoveryServices

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fkzk839%2FRecoveryServices%2Fmain%2Fmain.json)

## パラメーター

デプロイ時に以下のパラメーターを指定

- サブスクリプション : デプロイ対象のサブスクリプション
  - リソース グループ : 任意の名前で新規作成
- リージョン : japaneast
- Location : japaneast
- Admin Username : 任意のユーザー名 (OS ローカル管理者、ドメイン管理者)
- Admin Password : 複雑性の要件を満たした任意のパスワード (メモしておくこと)
- Domain Name : contoso.local のまま変更不要
- Resource Name Prefix : 6 文字以下の任意の文字列だが、デプロイされるリソースのリソース名に使用されるため、他者と重複せず自分だとわかるものにする。(xxx-bastion などになる)
- Vm Size : Standard_D2s_v3
- _artifacts Location : 変更不要
- Artifacts Location Sas Token : 空欄でよい

## 概要

Recovery Services ハンズオン用の Azure リソースをデプロイ

"prefix" の部分にはパラメーターの Resource Name Prefix が入る

- VNet (prefix-VNet) : 10.0.0.0/16
  - Subnet : 10.0.0.0/24
  - AzureBastionSubnet : 10.0.1.0/24
  - DNS : ドメイン コントローラーを指定 (10.0.0.4)
- Azure Bastion 用パブリック IP アドレス (prefix-bastion-ip)
- Azure Bastion (prefix-bastion)
- VM * 3
  - ドメイン コントローラー (prefix-DC) : 10.0.0.4
    - OS : Windows Server 2019 Datacenter
    - FW 無効化済み
    - データ ディスク 128 GB (F ドライブ)
    - ドメイン名 : contoso.local (昇格済み)
    - VM サイズ : Standard_D2s_v3
  - RecoveryVM1 (prefix-RecVM1) : 10.0.0.5
    - OS : Windows Server 2019 Datacenter
    - データ ディスク 128 GB (接続のみ)
    - ドメイン contoso.local に参加済み
    - VM サイズ : Standard_A2_v2
  - BackupServer (prefix-BKSvr) : 10.0.0.6
    - OS : Windows Server 2019 Datacenter
    - データ ディスク 128 GB (接続のみ)
    - ドメイン contoso.local に参加済み
    - VM サイズ : Standard_D2s_v3
- 各 VM 用 NIC