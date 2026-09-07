Étape 0 — Prérequis
Vérifie que tu as bien VAULT_ADDR positionné et que tu es loggué en admin :


export VAULT_ADDR='https://vault.devver.app:8200'
vault token lookup
Si ça échoue, reloggue-toi (vault login) avec ton root token.

Étape 1 — Appliquer setup-vault-for-terraform/
C'est le seul moment où les credentials B2 sont saisies à la main (Vault n'a pas encore le secret s3-backend puisque tout est supprimé) :


cd /home/victor/cluster-k8s-deployment/terraform/setup-vault-for-terraform

export VAULT_TOKEN=...          # ton token admin/root
export AWS_ACCESS_KEY_ID=...    # clés B2
export AWS_SECRET_ACCESS_KEY=...

terraform init -backend-config=backend.hcl
Avant l'apply, vérifie que backend.hcl a bien tes vraies valeurs de bucket/region/endpoint B2 (les mêmes que dans clusters/prod/backend.hcl) — dis-moi si ce n'est pas encore rempli, je le fais avec toi.


terraform apply -var='orgs=["prod"]'
Ça va créer : le mount KV v2 devver-infra-deployment, la policy terraform-backblaze-ro + son role AppRole (accès à s3-backend uniquement), et la policy terraform-prod-ro + son role AppRole (accès à proxmox + prod).

Récupère les role_id générés :


terraform output role_ids
terraform output backblaze_role_id
Étape 2 — Écrire les secrets dans Vault

vault kv put devver-infra-deployment/s3-backend key_id='...' application_key='...'
vault kv put devver-infra-deployment/proxmox token_id='root@pam!devver' token_secret='...'
vault kv put devver-infra-deployment/prod vm_user='devver' ssh_public_key='ssh-ed25519 ...'
Une fois cette étape 1 terminée, dis-moi et on enchaîne sur clusters/prod/ (génération du secret_id, puis init/plan/apply).

---

1. Vérifier que le secret_id AppRole pour prod existe (nouveau path terraform-orgs)

vault write -f auth/terraform-orgs/role/terraform-prod/secret-id
vault read -field=role_id auth/terraform-orgs/role/terraform-prod/role-id
2. Vérifier que les secrets sont bien écrits

vault kv get devver-infra-deployment/proxmox
vault kv get devver-infra-deployment/prod
Si l'un des deux manque (vm_user, ssh_public_key, token_id, token_secret), le plan échouera à l'étape de lecture Vault.

3. Récupérer les credentials B2 depuis Vault (plus besoin de les saisir à la main)

cd /home/victor/cluster-k8s-deployment/terraform/clusters/prod
source ../../fetch-b2-credentials.sh
Ce script a besoin soit de VAULT_TOKEN, soit de VAULT_ROLE_ID/VAULT_SECRET_ID (role terraform-backblaze) déjà exportés.

4. Exporter les credentials AppRole du cluster et init/plan

export TF_VAR_vault_role_id='<role_id récupéré étape 1>'
export TF_VAR_vault_secret_id='<secret_id récupéré étape 1>'

terraform init -backend-config=backend.hcl
terraform plan
Vérifie dans la sortie du plan : 5 VMs prévues (PROD-KUB-MASTER-1/2/3, PROD-KUB-WORKER-1/2), IP .100 à .104, template rocky9-cloud-template.

Dis-moi le résultat du plan avant qu'on passe à apply.

---

---
mdp automatiquement rensigné ?
quand clone bien modifier index sebnet
voir si beoin fair eautre chose quand clone niveua vault refaire le setup vault ?

etat cluster allumé éteint ...
peut être revoir l'organistation et enchainement script pour init des secret dune org dans le vault


voir cless ssh privée en plus ansiuble a faire rajouté à la copie
vérifiation plus besoin de rien
tester le tf
faire les pipelines et voir comment gerer les output que ansible a besoin