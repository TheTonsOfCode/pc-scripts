# PC Scripts

## clean-js

Cleans up old Node.js and Next.js projects by removing auto-generated files. This allows you to archive old source code while freeing up disk space.

**Usage:**

1.  Move all your old projects into a dedicated folder (e.g., `olds`).
2.  Navigate into the `olds` directory in your terminal: `cd olds`
3.  Run the `clean-js` script.
4.  The script will display a list of directories that will be removed. Review this list carefully.
5.  Type `yes` and press Enter to confirm the deletion.

## ipack

Packages local directories as if they were from a repository and automatically increments their versions. This tool was created for two main reasons:

1.  To simplify the process of packaging local code from any directory on your disk. It stores the generated `.tgz` files in a `.ipacks` folder within your home directory.
2.  To manage versions of these "local packages" by automatically incrementing the version number by one. This addresses an issue where installing a `.tgz` file created from a `package.json` with the same name as a previously installed package (e.g., `my-package-1.0.0.tgz`) but containing different internal files would be skipped by `npm`.

**Usage:**

Let's say you have two projects: **Project A** which you want to package, and **Project B** where you want to install the packaged version of Project A.

1.  **Choose an alias:** For Project A, let's choose the alias `my-lib`.

2.  **Navigate to Project A:** Open your terminal and navigate to the root directory of Project A.

3.  **Package Project A:** Run the following command:
    ```bash
    ipack pack my-lib
    ```
    This will package Project A and store it as a `.tgz` file in the `.ipacks` directory in your home directory, with an automatically incremented version number.

4.  **Navigate to Project B:** Now, navigate to the root directory of Project B in your terminal.

5.  **Install in Project B:** To install the packaged version of Project A in Project B, run:
    ```bash
    ipack i my-lib
    ```
    This command will locate the latest version of the `my-lib` package in your `.ipacks` directory and install it into Project B.

6.  **Updating the package:** If you make changes to Project A and want to update the version used in Project B, repeat the process starting from **step 2** in Project A: navigate to Project A's root directory and run `ipack pack my-lib` again. Then, navigate back to Project B and run `ipack i my-lib` to install the updated package.

If, for example, the `my-lib` package is built into a `dist` directory, run the command from the project root as follows:

`ipack pack my-lib dist`