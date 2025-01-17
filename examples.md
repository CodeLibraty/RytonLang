## примеры кода на Ryton

- Графический/Пользовательский интерфейс(UI) на RuVix:
```ryton
module import {
    std.RuVix.App
    std.RuVix.Effects
}

trash_cleaner = true

pack TextEditApp {
    init {
        this.ruvix = App.init(none)
        this.effects = Effects.init(this.ruvix)
        this.app = this.ruvix.create_app()
        
        this.setup_theme()
        this.create_ui()
        this.apply_effects()

        this.init_settings_handlers()
    }

    func setup_theme {
        this.app.theme_cls.theme_style = "Dark"
        this.app.theme_cls.primary_palette = "Blue"
        this.app.theme_cls.accent_palette = "Teal"
    }

    func create_ui {
        this.root = this.ruvix.create_widget('FloatLayout')
        this.ruvix.set_root(this.root)

        this.create_toolbar()
        this.create_editor()
        this.create_buttons()
        this.create_status_bar()
        
        this.add_widgets_to_root()
    }

    func create_toolbar {
        this.toolbar = this.ruvix.create_widget('TopAppBar',
            title="Simple TextEditor",
            size_hint=(0.90, 1),
            pos_hint={'top': 0.992, 'center_x': 0.5},
            md_bg_color=[0.1, 0.1, 0.15, 0.98],
            elevation=1
        )
    }

    func create_editor {
        this.editor = this.ruvix.create_widget('TextInput',
            size_hint=(0.95, 0.85),
            pos_hint={'center_x': 0.5, 'center_y': 0.45},
            background_color=[0.12, 0.12, 0.18, 1],
            foreground_color=[0.7, 0.8, 1, 1],
            cursor_color=[0, 0.7, 1, 1],
            font_name='JetBrainsMono',
            font_size=22,
            multiline=true
        )
    }

    func create_buttons {
        this.btn_save = this.ruvix.create_widget('IconButton',
            icon="content-save",
            pos_hint={'right': 0.95, 'top': 0.98},
            md_bg_color=[0.2, 0.3, 0.4, 0.3]
        )
    }

    func create_status_bar {
        this.status_bar = this.ruvix.create_widget('Label',
            text="",
            pos_hint={'x': 0.02, 'y': 0.02},
            theme_text_color="Custom",
            text_color=[0.5, 0.6, 0.7, 1]
        )
    }

    func init_settings_handlers {
        noop
    }

    func toggle_settings(instance) {
        if this.settings_menu.get_panel() not in this.root.children {
            this.root.add_widget(this.settings_menu.get_panel())
            this.settings_menu.show()
        } else {
            this.settings_menu.hide()
            this.root.remove_widget(this.settings_menu.get_panel())
        }
    }

    func apply_effects {
        this.effects.add_glow_effect(this.toolbar, 
            glow_size=7, 
            glow_color=(0, 0.7, 1, 0.2)
        )
        
        this.effects.add_color_effect(this.editor, 
            (0.20, 0.25, 0.30)
        )
        
        this.effects.add_fade_animation(this.btn_save, duration=2)
    }

    func add_widgets_to_root {
        for widget in [this.toolbar, this.editor, 
                      this.btn_save, 
                      this.status_bar] {
            this.ruvix.add_widget(this.root, widget)
        }
    }

    func run(this) {
        this.ruvix.run_app()
    }
}

app = TextEditApp()
app.run()
```
Стильный редактор текста в синих тонах с эффектами и анимациями

- Создание DSL языков
```ryton
module import {
    std.DSL
}

trash_cleaner = true

func Main {
    color_dsl = DSL.create_dsl("ColorDSL")

    func hex_to_rgb(hex_color) {
        hex_color = hex_color.lstrip('#')
        return tuple(int(hex_color [i:i+2], 16) for i in (0, 2, 4))
    }

    func rgb_to_hex(args, vars, funcs) {
        r, g, b = map(int, args)
        return f"#{r:02x}{g:02x}{b:02x}"
    }

    func blend_colors(args, vars, funcs) {
        color1, color2 = args
        if color1 in vars {
            color1 = vars [color1]
        }
        if color2 in vars {
            color2 = vars [color2]
        }

        rgb1 = hex_to_rgb(color1)
        rgb2 = hex_to_rgb(color2)
        
        blended = tuple(int((c1 + c2) / 2) for c1, c2 in zip(rgb1, rgb2))
        return f"#{blended [0]:02x}{blended [1]:02x}{blended [2]:02x}"
    }

    func store_color(args, vars, funcs) {
        name, color = args
        vars [name] = color
        return color
    }

    color_dsl.add_command("RGB", rgb_to_hex)
    color_dsl.add_command("BLEND", blend_colors)
    color_dsl.add_command("STORE", store_color)

    result = color_dsl.execute("""
    RGB 255 100 50
    STORE my_red #ff0000
    STORE my_blue #0000ff
    BLEND my_red my_blue
    """)

    // Выводим каждый результат отдельно
    for color in result {
        print(f"Color: {color}")
    }
}
```
Простой DSL для работы с цветами

- CLI программа:
```ryton

module import {
    std.Terminal[Terminal]
    std.ColoRize[set_all|colorize:clr|reset_color]
    std.DateTime[hours|minutes|seconds|time_short]
}

trash_cleaner = true

pack TerminalTime {
    init {
        this.term = Terminal()
    }

    func TUI(this) {
        this.term.set_title("TimeWin")
        this.term.hide_cursor()
        this.term_size = this.term.get_size()
        this.size = this.term_size.columns
        this.separator = "_" * this.size
        
        infinit 0.1 {
            this.now = time_short()
            this.now_time = this.now
            this.term.clear()
            print(this.separator)
            print(clr(this.term.print_ascii(this.now_time, 'slant'), color='cyan'))
            print(this.separator)
        }
    }
}

func Main {
    tt = TerminalTime()
    tt.TUI()
}
```
Простая программа для вывода времени в консоли c ascii и цветом

- Полноценная Оболочка коммндной строки:
```ryton
module import {
    std.Terminal[Terminal]
    std.Files
    std.System
    std.Path
    std.String[Regex]
    std.ErroRize[error]
    std.System:sys
    std.DateTime[now]
    std.MetaTable[MetaTable]
    std.ColoRize[set_all|reset_color|colorize:clrz]
    std.Shell[Shell]
}

trash_cleaner = true

term = Terminal()
mt   = MetaTable()
re   = Regex()
sh   = Shell()

pack DeltaShell {
    init {
        this.regime = 'linux'
        this.create_sessions()
    }

    // История команд
    table history {'commands': []}

    regimes = '''regimes:
     android   open cmd in connecteted Android device
     windows   open in Wine cmd Windows
     linux     open defult Linux Environment
    '''

    help_cmd = '''Created in RytonLang
    cmds:
     <void cmd> - clear screen
     help  - show this help
     exit  - exit shell'''

    // Алиасы команд
    table aliases {
        'ls': "Files.list_dir()",
        'cd': "sh.cd()", 
        'pwd': "Path.pwd()",
        'cat': "Files.read_file()",
        'clear': "Terminal.clear()",
        'help': "print(help_cmd)"
    }

    func parse_command(this, cmd) {
        parts = cmd.split()
        if parts [0] in aliases {
            if parts [0] == 'cd' {
                return sh.cd(parts[1])
            }
            parts [0] = aliases [parts [0]]
        }
        return parts
    }

    func create_sessions() {
        // Создаем интерактивные сессии
        this.android_shell = sh.create_interactive('adb shell')
        this.windows_shell = sh.create_interactive('wine cmd /c')
    }

    func execute_command(this, cmd) {
        parts = cmd.split()
        command = parts [0]
        args = parts [1] if len(parts) > 1 else ""

        if command == "cd" {
            if this.regime == 'android' {
                noop
            } else {
                if args == "" {
                    output = sh.cd(Path.get_home())
                } else {
                    output = sh.cd(args)
                }

                if output == True {
                    noop
                } elif output == False {
                    print(f"Directory not found {args}")
                }
            }
        } else {
            try {
                if this.regime == 'linux' {
                    result = sh.rt_run(cmd)
                } elif this.regime == 'windows' {
                    result = sh.run(f'wine cmd.exe /k {cmd}')
                } elif this.regime == 'android' {
                    result = this.android_shell.execute(cmd)
                }
                print(result)
            } elerr Exception as err {
                error(f"Command not found: {cmd}$N{err}")
            }
        }
    }


    func size_term(this) {
        info = term.terminal_info()
        size_cmd = info ['size'][0]

        return size_cmd
    }

    func current_dir(this) {
        dir = Path.pwd()
        home_dir = Path.get_home()
        dir = dir.replace(home_dir, '~')
        return dir
    }

    func shell_prompt(this) {
        indent = this.size_term()
        user = f'{sys.login_name()}/{this.regime} '

        start_line = term.symbol('round_dr') + term.symbol('box_h')
        indent = indent - len(f"{start_line} {this.current_dir()}") - len(user)
        indent_line = ' ' * indent

        line = f"{start_line} {this.current_dir()}{indent_line}{user}" 

        print(line, end="")
    }

    func main(this) {
        term.clear()
        term.rule("Delta Shell v0.1")
        print(this.help_cmd)

        infinit 0.05 {
            this.shell_prompt()

            cmd = input(f"{term.symbol('round_ur')}{term.symbol('line_h')} ")

            if cmd == "exit" {
                break
            }

            elif cmd == 'windows' {
                this.regime = 'windows'
            } elif cmd == 'linux' {
                this.regime = 'linux'
            } elif cmd == 'android' {
                this.regime = 'android'
            } elif cmd == 'regime' {
                print(regime)
            }
            elif cmd == "" {
                term.clear()
            }

            elif cmd {
                this.history ['commands'].append(cmd)
                this.execute_command(cmd)
            }
        }
    }
}

shell = DeltaShell()
try {
    shell.main()
} elerr KeyboardInterrupt {
    print('$NSession exit')
}
```
Это пример демонстрирует качественной и простой в написании командной обочки для posix систем

- Пример использования Zig интеграции:
1. исполняет код на месте:
```ryton
trash_cleaner = true

func Main {
    print("Hello From Ryton")
    #Zig(start)
    const std = @import("std");
    const print = std.debug.print;

    pub fn main() void {
        print("Hello From Zig\\n", .{});
    }
    #Zig(end: var)
}
```
В этом примере мы используем интеграцию с Zig, чтобы вызвать скомпилировать и запустить простой код на Zig
2. создание модуля на Zig:
```ryton
trash_cleaner = true
func Main {
    print("Hello From Ryton")
    #ZigModule(
    const std = @import("std");
    const print = std.debug.print;

    pub fn main() void {
        print("Hello From Zig\\n", .{});
    }
    ) -> hello_world // модуль будет называться hello_world

    hello_world.main() // вызываем функцию из модуля
    и получеам в терминал "Hello From Zig"
}
```
в этом примере мы используем интеграцию с Zig, чтобы создать модуль на Zig и вызвать функцию из него