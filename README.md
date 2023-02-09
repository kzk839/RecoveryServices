# Deploy Lab Env for RecoveryServices

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fkzk839%2FRecoveryServices%2Fmain%2Fmain.json)

## パラメーター

デプロイ時に以下のパラメーターを指定

| 項目                         | 概要                                                                                                                                               |
|------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|
| サブスクリプション           | デプロイ対象のサブスクリプション                                                                                                                   |
| リソース グループ            | 任意の名前で新規作成                                                                                                                               |
| リージョン                   | japaneast                                                                                                                                          |
| Location                     | japaneast                                                                                                                                          |
| Admin Username               | 任意のユーザー名 (OS ローカル管理者、ドメイン管理者)                                                                                               |
| Admin Password               | 複雑性の要件を満たした任意のパスワード (メモしておくこと)                                                                                          |
| Domain Name                  | contoso.local のまま変更不要                                                                                                                       |
| Resource Name Prefix         | 6 文字以下の任意の文字列だが、デプロイされるリソースのリソース名に使用されるため、他者と重複せず自分だとわかるものにする。(xxx-bastion などになる) |
| Vm Size                      | Standard_D2s_v3                                                                                                                                    |
| _artifacts Location          | 変更不要                                                                                                                                           |
| Artifacts Location Sas Token | 空欄でよい                                                                                                                                         |

<img width="574" alt="2023-02-04_22h26_16" src="https://user-images.githubusercontent.com/67820613/216857560-20a4bbb0-b46c-4d7f-bec0-f2a676e245de.png">

## 概要

Recovery Services ハンズオン用の Azure リソースをデプロイ

"prefix" の部分にはパラメーターの Resource Name Prefix が入る

- VNet (prefix-VNet) : 10.0.0.0/16
  - Subnet : 10.0.0.0/24
  - AzureBastionSubnet : 10.0.1.0/24
  - DNS : ドメイン コントローラーを指定 (10.0.0.4)
- Azure Bastion 用パブリック IP アドレス (prefix-bastion-ip)
- Azure Bastion (prefix-bastion)
- VM * 5
  - ドメイン コントローラー (prefix-DC) : 10.0.0.4
    - OS : Windows Server 2019 Datacenter
    - FW 無効化済み
    - データ ディスク : 128 GB (F ドライブ)
    - ドメイン名 : contoso.local (昇格済み)
    - VM サイズ : Standard_D2s_v3
  - RecoveryVM1 (prefix-RecVM1) : 10.0.0.5
    - OS : Windows Server 2019 Datacenter
    - データ ディスク : 128 GB (接続のみ)
    - ドメイン contoso.local に参加済み
    - VM サイズ : Standard_A2_v2
  - BackupServer (prefix-BKSvr) : 10.0.0.6
    - OS : Windows Server 2019 Datacenter
    - データ ディスク : 128GB (OS 内でフォーマットが必要)
    - ドメイン contoso.local に参加済み
    - VM サイズ : Standard_D2s_v3
  - 構成/プロセス サーバー (prefix-CSPSSvr) : 10.0.0.7
    - OS : Windows Server 2016 Datacenter
    - データ ディスク : 128GB (OS 内でフォーマットが必要)
    - ドメイン未参加
    - VM サイズ : Standard_D2s_v3
  - ASR 対象サーバー (prefix-Migrated) : 10.0.0.8
    - OS : Windows Server 2016 Datacenter
    - データ ディスク : なし
    - ドメイン未参加
    - VM サイズ : Standard_A2_v2
- VM 用 NIC * 5
- キャッシュ ストレージ アカウント (prefix の後にランダムな 13 文字)
    - SKU : Standard_LRS

## 注意点
Recovery Services コンテナー、ASR 対象サーバー共に東日本リージョンにデプロイされるため、東日本リージョン ⇒ 東日本リージョンでの DR テストとなる。
