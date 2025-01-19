# Ryton Programming Language

Ryton is a modern, multi-paradigm and multi-platform high-level programming language that makes the right simple and the complex understandable.

![Logo](card.png)

Ryton follows the philosophy of "if you want better - make it simple", providing developers with modern tools in the most understandable form. All Ryton projects are distributed under a special open license, forming an ecosystem of high-quality and transparent software.

Ryton is a language for those who value simplicity, performance and openness in the development of professional software.

## Features

- Under the hood CPython
- Ability to compile and build a Ryton project into native C code using the RytonBuilder tool using Nuitka
- Extensive standard library
- Multiplatform support
- the ability to import and use libraries written in other languages. Such as Zig, Python and JVM (embedded and jar files)
- Ability to call [ZigLang](https://github.com/ziglang/zig) code directly from Ryton code (embedded in Ryton) see syntax [examples.md](examples.md)
- Clean and intuitive syntax
- Built-in DSL support
- Powerful metaprogramming system

## What can Ryton be used for
- Mobile application development
- Game development
- Web application development
- Server application development
- Desktop application development
- Development of development tools
- Professional Software development
- AI and ML development

## Swiss knife?
Unlike "all-in-one" languages, Ryton uses the best tools for specific tasks:

- Need performance? Use Zig
- Need ML libraries? Take from Python
- Need enterprise solutions? Connecting Java

This is not "can do everything and nothing", but competent specialization through integration. Each component does what it is strong in:
- Zig -> system programming
- Python -> machine learning
- Java -> enterprise solutions
- Ryton -> convenient modern syntax and tying everything together

This approach allows:
1. Reusing existing code
2. Choosing the optimal tool for the task
3. Flexibility in development
4. Performance where it is needed

just choose the necessary tools and you can write code! without unnecessary hassle, moms, dads and loans for a psychologist

## Quick start
- build from sources
```bash
git clone https://github.com/CodeLibraty/RytonLang.git
cd RytonLang
python3 -m venv ryton_venv
source ryton_venv/bin/activate
./build.sh
```
After a successful build, you will get the executable file ryton_laucnher.bin at ./dist/ryton_launcher.dist/ryton_laucnher.bin.
**Warning**: this file must be run from the dist/ryton_launcher.dist/ folder, otherwise it will not work (dependencies will not be found)
**Note**: this repository does not contain the executable file of Zig and its libraries. You need to install and copy them manually to the ./Interpritator/Ziglang/ folder

- We recommend installing additional libraries for RytonLang:
- For Ubuntu-like systems
```bash
sudo apt install ccache
```
- For Arch-like systems
```bash
sudo pacman -S ccache
```

- **Note**: RytonLang is not officially supported on Windows. Some libraries may work incorrectly or not work at all. Which in the worst case can lead to a Windows crash.
We recommend using WSL for Windows or full-fledged Linux (Ubuntu, Manjaro, Arch, Alpine) to work with RytonLang.

## Code examples
```
module import {
std.UpIO
}

func Main {
print('Hello World')
}
```
*see more code examples in* [examples.md](examples.md)

License
Copyright (c) 2025 CodeLibraty team. See [LICENSE](LICENSE) for details.

Team
- RejziDich - Lead Developer
- CodeLibraty team - Core Team

Contacts
- GitHub: https://github.com/Rejzi-dich/RytonLang
- EMail: rejzidich@gmail.com or rejzi@drt.com(unstable)

Community
- Site project: https://ryton.vercel.app
- Site team: https://siteclt.vercel.app
- Discord: https://discord.com/invite/D2hqwn94rs