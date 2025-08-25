{
  description = "A Python Package";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        ## Import nixpkgs:
        pkgs = import nixpkgs { inherit system; };

        ## Import the lib thingamajig
        inherit (nixpkgs) lib;

        ## Read pyproject.toml file:
        pyproject = builtins.fromTOML (builtins.readFile ./pyproject.toml);

        ## Get project specification:
        project = pyproject.project;

        ## Get the package:
        package = pkgs.python313Packages.buildPythonPackage {
          ## Set the package name:
          pname = project.name;

          ## Inherit the package version:
          inherit (project) version;

          ## Set the package format:
          format = "pyproject";

          ## Set the package source:
          src = ./.;

          ## Specify the build system to use:
          build-system = with pkgs.python313Packages; [
            setuptools
          ];

          ## Specify test dependencies:
          nativeCheckInputs = [
            ## Python dependencies:
            pkgs.python313Packages.mypy
            pkgs.python313Packages.nox
            pkgs.python313Packages.pytest
            pkgs.python313Packages.ruff

            ## Non-Python dependencies:
            pkgs.uv
            pkgs.taplo
          ];

          ## Define the check phase:
          checkPhase = ''
            runHook preCheck
            nox
            runHook postCheck
          '';

          ## Specify production dependencies:
          propagatedBuildInputs = [
            pkgs.python313Packages.click
            pkgs.python313Packages.numpy
            pkgs.python313Packages.torchWithRocm
          ];
        };

        ## Make our package editable:
        editablePackage = pkgs.python313.pkgs.mkPythonEditablePackage {
          pname = project.name;
          inherit (project) scripts version;
          root = "$PWD";
        };
      in
      {
        ## Project packages output. This does not work on its own, the propagated build inputs must match. For now this is fine as I will only ever use the devshells until future notice:
        packages = {
          "${project.name}" = package;
          default = self.packages.${system}.${project.name};
        };

        ## Project development shell output:
        devShells = {
          default = pkgs.mkShell {
            inputsFrom = [
              package
            ];

            buildInputs = [
              #################
              ## OUR PACKAGE ##
              #################

              editablePackage

              #################
              # VARIOUS TOOLS #
              #################

              pkgs.python3Packages.build
              pkgs.python3Packages.ipython

              ####################
              # EDITOR/LSP TOOLS #
              ####################

              # LSP server:
              pkgs.python3Packages.python-lsp-server

              # LSP server plugins of interest:
              pkgs.python3Packages.pylsp-mypy
              pkgs.python3Packages.pylsp-rope
              pkgs.python3Packages.python-lsp-ruff
            ];
          };
        };
      }
    );
}
