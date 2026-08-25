# Installation example

```powershell
git clone <security-pack-repository>
git clone <application-repository>

pwsh -NoProfile -File ./copilot-security-pack/installer/install.ps1 `
  -TargetRepo ./application-repository

cd ./application-repository
git diff
```

After review, commit the generated repository-native Copilot customization through the application's normal pull-request process.
