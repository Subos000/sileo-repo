# Subos000 Sileo Repo

Subos000 的 Sileo 越狱软件源

## 添加源

```
https://subos000.github.io/sileo-repo
```

## 分类

| 分类 | 说明 |
|------|------|
| Roothide 插件 | 基于 roothide 越狱的插件 |


## 使用说明

1. 将 `.deb` 文件放入对应分类的 `debs/` 目录
2. 运行 `bash gen.sh` 重新生成 Packages 和 Release 文件
3. 提交并推送至 GitHub

## 自动化

每次推送至 `main` 分支后，GitHub Actions 会自动重新生成 Packages 和 Release 文件。
