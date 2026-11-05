# Disabled workflows

GitHub only accepts workflow files from tokens with the `workflow` scope. The
initial push used a token without that scope, so the CI definitions live here
instead of `.github/workflows/`.

To enable them, sign in with a token that has the `workflow` scope and move the
files back:

```sh
git mv .github/workflows-disabled/*.yml .github/workflows/
git commit -m "Enable CI workflows"
git push
```
