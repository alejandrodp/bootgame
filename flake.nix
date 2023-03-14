{
  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      inherit (self.packages.${system}) bootgame;
    in
    with pkgs.lib; {
      formatter.${system} = pkgs.nixpkgs-fmt;

      apps.${system}.default = {
        type = "app";

        program =
          let
            run-qemu =
              { bootgame, qemu, writeShellScript }:
              writeShellScript "run-qemu" ''
                HDA=$(mktemp)
                cp ${bootgame} $HDA

                ${qemu}/bin/qemu-system-i386 -drive format=raw,file=$HDA
                rm $HDA
              '';
          in
          (pkgs.callPackage run-qemu { inherit bootgame; }).outPath;
      };

      packages.${system} = {
        default = bootgame;

        bootgame =
          let
            drv =
              { python3, stdenv }:
              stdenv.mkDerivation {
                pname = "bootgame";
                version = "1.0.0";

                src = ./.;

                nativeBuildInputs = [
                  (python3.withPackages (py: [ py.pillow ]))
                ];

                preBuild = ''
                  patchShebangs png2mode13h.py
                '';

                installPhase = ''
                  cp tarea.img $out
                '';
              };
          in
          pkgs.callPackage drv { };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          gnumake
          qemu
          gdb
        ];

        inputsFrom = [ bootgame ];
      };
    };
}
