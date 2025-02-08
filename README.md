# Xenomai Torizon OS Tests

Tests that sanity check Xenomai status on Torizon OS.

## Running Tests

For Xenomai 4 (EVL core):

```bash
sh -c "$(curl -sSL https://raw.githubusercontent.com/leograba/xenomai-torizon-tests/refs/heads/main/xenomai4-torizon-tests.sh)"
```

For Xenomai 3 (Cobalt core):

```bash
sh -c "$(curl -sSL https://raw.githubusercontent.com/leograba/xenomai-torizon-tests/refs/heads/main/xenomai3-torizon-tests.sh)"
```

## Running Tests From Local Repo

This is useful while developing the scripts.

Run the tests from VS Code (`Ctrl + Shift + B` or use the [task runner](https://marketplace.visualstudio.com/items?itemName=microhobby.taskrunnercodeplus)):

![Run from VS Code Task Runner](.multimedia/run-vscode.png)

Run the tests from the command-line.

For Xenomai 4 (EVL core):

```bash
./deploy.sh 4
```

For Xenomai 3 (Cobalt core):

```bash
./deploy.sh 3
```
