from direct.showbase.ShowBase import ShowBase
from panda3d.core import *
from panda3d.bullet import *
from direct.task import Task


class Game3D(ShowBase):
    def __init__(self):
        # Принудительно используем базовый GLX конвейер
        loadPrcFileData("", """
        load-display pandagl
        window-type none
        audio-library-name null
        gl-version 1 4
        sync-video false
        """)
        
        # Инициализация базового конвейера
        pipe = GraphicsPipeSelection.getGlobalPtr().makeDefaultPipe()
        
        # Создаем базовое окно через GLX
        ShowBase.__init__(self, pipe=pipe)
        
        # Настраиваем окно
        props = WindowProperties()
        props.setSize(800, 600)
        props.setTitle('Ryton Racing')
        self.openMainWindow(props=props)
        
        # Инициализация физики
        self.physics_world = BulletWorld()
        self.physics_world.setGravity(Vec3(0, 0, -9.81))

    def update_key(self, key, value):
        self.keys[key] = value

    def update_physics(self, task):
        dt = globalClock.getDt()
        self.physics_world.doPhysics(dt)
        return Task.cont

    def create_scene(self, name):
        self.scenes[name] = NodePath(name)
        self.scenes[name].reparentTo(self.render)
        
    def create_track(self, scene, width=10, length=100):
        # Создаем трассу
        track = self.loader.loadModel("models/box")
        track.setScale(width, length, 0.1)
        track.setPos(0, length/2, -0.1)
        track.reparentTo(self.scenes[scene])
        
        # Физика для трассы
        shape = BulletBoxShape(Vec3(width, length, 0.1))
        node = BulletRigidBodyNode('Track')
        node.addShape(shape)
        np = self.scenes[scene].attachNewNode(node)
        np.setPos(0, length/2, -0.1)
        self.physics_world.attachRigidBody(node)
        
        # Бортики
        self.create_wall(scene, Vec3(-width, length/2, 1), Vec3(0.1, length, 2))
        self.create_wall(scene, Vec3(width, length/2, 1), Vec3(0.1, length, 2))

    def create_wall(self, scene, pos, scale):
        wall = self.loader.loadModel("models/box")
        wall.setPos(pos)
        wall.setScale(scale)
        wall.reparentTo(self.scenes[scene])
        
        shape = BulletBoxShape(scale)
        node = BulletRigidBodyNode('Wall')
        node.addShape(shape)
        np = self.scenes[scene].attachNewNode(node)
        np.setPos(pos)
        self.physics_world.attachRigidBody(node)

    def create_car(self, scene, pos=(0,0,1)):
        # Создаем RigidBody для машины
        shape = BulletBoxShape(Vec3(1, 2, 0.5))
        car_node = BulletRigidBodyNode('Car')
        car_node.addShape(shape)
        car_node.setMass(1000.0)
        
        # Создаем vehicle
        vehicle = BulletVehicle(self.physics_world, car_node)
        vehicle.setCoordinateSystem(ZUp)
        self.physics_world.attachVehicle(vehicle)
        
        # Визуальная модель
        car_model = self.loader.loadModel("models/box")
        car_model.setScale(1, 2, 0.5)
        car_model.setPos(*pos)
        car_model.reparentTo(self.scenes[scene])
        
        # Создаем визуальную модель колеса
        wheel_model = self.loader.loadModel("models/box")
        wheel_model.setScale(0.3, 0.3, 0.2)
        
        # Добавляем колеса
        wheel_shape = BulletCylinderShape(0.3, 0.2)
        for i in range(4):
            x = -0.8 if i % 2 == 0 else 0.8
            y = -1.2 if i < 2 else 1.2
            wheel = vehicle.createWheel()
            wheel.setNode(wheel_model.node())
            wheel.setChassisConnectionPointCs(Point3(x, y, -0.5))
            wheel.setFrictionSlip(100.0)
            wheel.setMaxSuspensionForce(4000.0)
            wheel.setSuspensionStiffness(40.0)
            wheel.setWheelsDampingRelaxation(2.3)
            wheel.setWheelsDampingCompression(4.4)
            wheel.setRollInfluence(0.1)
        
        return vehicle

    def setup_camera(self, target, distance=20):
        # Получаем NodePath от физического объекта
        target_np = self.render.attachNewNode(target.get_chassis())
        self.camera.reparentTo(target_np)
        self.camera.setPos(0, -distance, distance/2)
        self.camera.lookAt(target_np)

    def add_light(self, scene, name, type="point", color=(1,1,1)):
        if type == "point":
            light = PointLight(name)
        elif type == "directional":
            light = DirectionalLight(name)
        elif type == "ambient":
            light = AmbientLight(name)
        light_color = LVecBase4f(color[0], color[1], color[2], 1.0)
        light.setColor(light_color)
        self.lights[name] = self.scenes[scene].attachNewNode(light)
        self.scenes[scene].setLight(self.lights[name])

    def control_car(self, car, speed=10.0, turn_rate=0.5):
        if self.keys.get("up"):
            car.applyCentralForce(Vec3(0, speed, 0))
        if self.keys.get("down"):
            car.applyCentralForce(Vec3(0, -speed, 0))
        if self.keys.get("left"):
            car.applyTorqueImpulse(Vec3(0, 0, turn_rate))
        if self.keys.get("right"):
            car.applyTorqueImpulse(Vec3(0, 0, -turn_rate))
