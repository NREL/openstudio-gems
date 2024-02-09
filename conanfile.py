import os

from conan import ConanFile
from conan.tools.env import Environment, VirtualBuildEnv
from conan.tools.microsoft import is_msvc, VCVars


class GemsRecipe(ConanFile):
    settings = "os", "compiler", "build_type", "arch"

    def build_requirements(self):
        if is_msvc(self):
            self.tool_requires("ruby/3.2.2")
        self.tool_requires("sqlite3/3.38.5")

    def generate(self):
        venv = VirtualBuildEnv(self)
        venv.generate()

        env = Environment()
        env.define("GEM_HOME", os.path.abspath("gems"))
        env.define("GEM_PATH", os.path.abspath("gems"))
        env.vars(self, scope="build").save_script("conanbuild_gems")

        if is_msvc(self):
            vc = VCVars(self)
            vc.generate()
