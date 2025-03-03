import pyglet
from .camera import Camera

class Tile:
    def __init__(self, sprite_path, x, y, solid):
        self.sprite = pyglet.image.load(sprite_path)
        self.sprite.anchor_x = self.sprite.width // 2
        self.sprite.anchor_y = self.sprite.height // 2
        self.x = x
        self.y = y
        self.solid = solid
        self.sprite_obj = None
        
    def set_collider(self, shape, size):
        if self.solid:
            self.collider = {"shape": shape, "size": size}

    def create_sprite(self, batch, type):
        self.sprite_obj = pyglet.sprite.Sprite(
            self.sprite,
            x=self.x,
            y=self.y,
            batch=batch
        )
        if type == "tile":
            scale_x = 90 / self.sprite.width
            scale_y = 90 / self.sprite.height
            self.sprite_obj.scale_x = scale_x
            self.sprite_obj.scale_y = scale_y
        elif type == "decoration":
            pass


class TileLayer:
    def __init__(self, grid_size=32):
        self.grid_size = grid_size
        self.tiles = {}
        self.batch = None
        
    def add_tile(self, grid_x, grid_y, sprite_path, shape="box"):
        world_x = grid_x * self.grid_size
        world_y = grid_y * self.grid_size
        
        tile = Tile(sprite_path, world_x, world_y, True)
        tile.set_collider(shape, (self.grid_size, self.grid_size))
        self.tiles[(grid_x, grid_y)] = tile

class DecorationLayer:
    def __init__(self):
        self.decorations = []
        self.batch = None
        
    def add_decoration(self, x, y, sprite_path, solid=False):
        decoration = Tile(sprite_path, x, y, solid)
        self.decorations.append(decoration)

class Tilemap:
    def __init__(self, grid_size=32):
        self.tile_layer = TileLayer(grid_size)
        self.decoration_layer = DecorationLayer()
        
    def start(self):
        print("Starting tilemap")
        self.batch = self.game_object.scene.window.graphics.batch

    def load_from_file(self, map_file):
        with open(map_file) as f:
            current_diaposon = None
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'): continue
                
                if line.startswith('diaposon'):
                    current_diaposon = []
                    continue
                    
                if current_diaposon is not None:
                    if line.endswith(';'):
                        # Parse diapason
                        current_diaposon.append(line[:-1])
                        layer = current_diaposon[0].strip('| ')
                        coords1 = current_diaposon[1].strip('| ').split(',')
                        coords2 = current_diaposon[2].strip('| ').split(',')
                        x1, y1 = int(coords1[0]), int(coords1[1])
                        x2, y2 = int(coords2[0]), int(coords2[1])
                        sprite = current_diaposon[3].strip('| ')
                        
                        # Fill the range
                        for x in range(x1, x2+1):
                            for y in range(y1, y2+1):
                                if layer == "tile":
                                    self.tile_layer.add_tile(x, y, sprite, "box")
                                else:
                                    self.decoration_layer.add_decoration(x*32, y*32, sprite, False)
                                    
                        current_diaposon = None
                    else:
                        current_diaposon.append(line)
                    continue
                
                # Regular tiles
                layer, x, y, sprite, solid, shape = line.strip().split(',')
                if layer == "tile":
                    self.tile_layer.add_tile(int(x), int(y), sprite, shape)
                else:
                    self.decoration_layer.add_decoration(float(x), float(y), sprite, solid == "true")

        # Create sprites after loading
        print(f"Creating {len(self.tile_layer.tiles)} tile sprites")
        for tile in self.tile_layer.tiles.values():
            tile.create_sprite(self.batch, type="tile")
            
        print(f"Creating {len(self.decoration_layer.decorations)} decoration sprites")
        for decoration in self.decoration_layer.decorations:
            decoration.create_sprite(self.batch, type="decoration")


    def update(self, dt):
        camera = self.game_object.scene.get_component(Camera)
        if camera:
            # Update tile layer
            for tile in self.tile_layer.tiles.values():
                screen_x, screen_y = camera.world_to_screen(tile.x, tile.y)
                if tile.sprite_obj:
                    tile.sprite_obj.x = screen_x
                    tile.sprite_obj.y = screen_y
                    tile.sprite_obj.scale = camera.zoom
                    
            # Update decoration layer
            for decoration in self.decoration_layer.decorations:
                screen_x, screen_y = camera.world_to_screen(decoration.x, decoration.y)
                if decoration.sprite_obj:
                    decoration.sprite_obj.x = screen_x
                    decoration.sprite_obj.y = screen_y
                    decoration.sprite_obj.scale = camera.zoom
