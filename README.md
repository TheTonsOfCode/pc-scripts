# PC Scripts

## clean-js

Cleans up old Node.js and Next.js projects by removing auto-generated files. This allows you to archive old source code while freeing up disk space.

**Usage:**

1.  Move all your old projects into a dedicated folder (e.g., `olds`).
2.  Navigate into the `olds` directory in your terminal: `cd olds`
3.  Run the `clean-js` script.
4.  The script will display a list of directories that will be removed. Review this list carefully.
5.  Type `yes` and press Enter to confirm the deletion.

## localpack

Packages local directories as if they were from a repository and automatically increments their versions. This tool was created for two main reasons:

1.  To simplify the process of packaging local code from any directory on your disk. It stores the generated `.tgz` files in a `.localpacks` folder within your home directory.
2.  To manage versions of these "local packages" by automatically incrementing the version number by one. This addresses an issue where installing a `.tgz` file created from a `package.json` with the same name as a previously installed package (e.g., `my-package-1.0.0.tgz`) but containing different internal files would be skipped by `npm`.

**Usage:**

Let's say you have two projects: **Project A** which you want to package, and **Project B** where you want to install the packaged version of Project A.

1.  **Choose an alias:** For Project A, let's choose the alias `my-lib`.

2.  **Navigate to Project A:** Open your terminal and navigate to the root directory of Project A.

3.  **Package Project A:** Run the following command:
    ```bash
    localpack pack my-lib
    ```
    This will package Project A and store it as a `.tgz` file in the `.localpacks` directory in your home directory, with an automatically incremented version number.

4.  **Navigate to Project B:** Now, navigate to the root directory of Project B in your terminal.

5.  **Install in Project B:** To install the packaged version of Project A in Project B, run:
    ```bash
    localpack i my-lib
    ```
    This command will locate the latest version of the `my-lib` package in your `.localpacks` directory and install it into Project B.

6.  **Updating the package:** If you make changes to Project A and want to update the version used in Project B, repeat the process starting from **step 2** in Project A: navigate to Project A's root directory and run `localpack pack my-lib` again. Then, navigate back to Project B and run `localpack i my-lib` to install the updated package.

If, for example, the `my-lib` package is built into a `dist` directory, run the command from the project root as follows:

`localpack pack my-lib dist`

### localpack Convenience Configuration

To streamline the usage of `localpack` and avoid repeatedly typing the alias and the `pack` or `i` commands, you can create an `localpack.json` file in your projects.

**Project A (where you package):**

Create an `localpack.json` file in the root directory of Project A with the following structure:

```json
{
  "alias": "your-package-alias",
  "directory": "optional-directory"
}
```

* `"alias"`: Replace `"your-package-alias"` with the desired alias for your package (e.g., `"my-lib"`).
* `"directory"` (optional): If your package contents are located in a specific subdirectory (like `dist`), specify it here. This corresponds to the third parameter of the `localpack pack` command.

**Project B (where you install):**

Create an `localpack.json` file in the root directory of Project B with the following structure:

```json
{
  "packs": [
    "package-alias-to-install-1",
    "package-alias-to-install-2"
  ]
}
```

* `"packs"`: This is an array containing the aliases of the packages you want to install (e.g., `["my-lib"]`).

**Updated Usage:**

With these `localpack.json` files in place, the usage becomes even simpler:

1.  **Navigate to Project A:** Open your terminal and navigate to the root directory of Project A.

2.  **Package Project A:** Now you can simply run:
    ```bash
    localpack
    ```
    If an `"alias"` key is found in `localpack.json`, `localpack` will automatically package the project using the specified alias and the optional `"directory"`.

3.  **Navigate to Project B:** Navigate to the root directory of Project B in your terminal.

4.  **Install in Project B:** You can now simply run:
    ```bash
    localpack
    ```
    If a `"packs"` key is found in `localpack.json`, `localpack` will automatically install each of the packages listed in the `"packs"` array.

5.  **Updating the package:** If you make changes to Project A, navigate to its root directory and run `localpack`. Then, navigate back to Project B and run `localpack` to install the updated package.