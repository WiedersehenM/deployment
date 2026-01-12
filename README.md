## Install Terraform

If you use a package manager to install software on your macOS, Windows, or Linux system, you can use it to install Terraform.

First, install the HashiCorp tap, which is Hashicorp's official repository of all our Homebrew packages.

```bash
brew tap hashicorp/tap
```

Now, install Terraform from hashicorp/tap/terraform.

```bash
brew install hashicorp/tap/terraform
```

You can check your current Terraform version by running the terraform -version command.

```bash
terraform -version
```

## Write configuration

Terraform configuration files are plain text files in HashiCorp's configuration language, HCL, with file names ending with `.tf`. When you perform operations with the Terraform CLI, Terraform loads all of the configuration files in the current working directory and automatically resolves dependencies within your configuration. This allows you to organize your configuration into multiple files and in any order you choose.

We recommend using consistent formatting to ensure readability. The terraform fmt command automatically reformats all configuration files in the current directory according to HashiCorp's recommended style.

In your terminal, use Terraform to format your configuration files.

```bash
terraform fmt
```

## Initialize your workspace

Before you can apply your configuration, you must initialize your Terraform workspace with the terraform init command. As part of initialization, Terraform downloads and installs the providers defined in your configuration in your current working directory.

Initialize your Terraform workspace.

```bash
terraform init
```

Make sure your configuration is syntactically valid and internally consistent by using the terraform validate command.

```bash
terraform validate
```

## Create infrastructure

Terraform makes changes to your infrastructure in two steps.

Terraform creates an execution plan for the changes it will make. Review this plan to ensure that Terraform will make the changes you expect.

Once you approve the execution plan, Terraform applies those changes using your workspace's providers.

This workflow ensures that you can detect and resolve any unexpected problems with your configuration before Terraform makes changes to your infrastructure.

```bash
cd envs/dev

terraform apply
```

## Inspect state

When you applied your configuration, Terraform wrote data about your infrastructure into a file called `terraform.tfstate`. Terraform stores data about your infrastructure in its state file, which it uses to manage resources over their lifecycle.

List the resources and data sources in your Terraform workspace's state with the `terraform state list` command.

```bash
terraform state list
```

Even though the data source is not an actual resource, Terraform tracks it in your state file. Print out your workspace's entire state using the `terraform show` command.

```bash
terraform show
```

当ec2 创建成功时，使用ssh 命令登录ec2 并在 /mnt/efs 目录下手动添加config.toml 配置文件

```bash
ssh -i ../../modules/ec2/efs-editor-key.pem ec2-user@$(terraform output -raw ec2_ip)
```

在envs/dev 下创建 terraform.tfvars 并填入数据库用户名和密码字段

```bash
db_username = "gitmega"
db_password = "password"
```

当创建完资源后，如果terraform 不再管理这些资源，需要删除state

``` bash
terraform state list | while read r; do terraform state rm "$r"; done
```
