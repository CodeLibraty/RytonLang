

class Animation:
    def __init__(self, target):
        self.target = target
        self.duration = 0
        self.elapsed = 0
        self.running = False
        self.actions = []  # Очередь анимаций
        
    def move_to(self, x, y, duration):
        self.actions.append({
            'type': 'move',
            'start_x': self.target.x,
            'start_y': self.target.y,
            'end_x': x,
            'end_y': y,
            'duration': duration,
            'elapsed': 0
        })
        return self
        
    def rotate_to(self, angle, duration):
        self.actions.append({
            'type': 'rotate',
            'start_angle': self.target.rotation,
            'end_angle': angle,
            'duration': duration,
            'elapsed': 0
        })
        return self
        
    def scale_to(self, scale, duration):
        self.actions.append({
            'type': 'scale',
            'start_scale': self.target.scale,
            'end_scale': scale,
            'duration': duration,
            'elapsed': 0
        })
        return self

    def update(self, dt):
        if not self.actions:
            return
            
        current = self.actions[0]
        current['elapsed'] += dt
        progress = min(1.0, current['elapsed'] / current['duration'])
        
        if current['type'] == 'move':
            new_x = current['start_x'] + (current['end_x'] - current['start_x']) * progress
            new_y = current['start_y'] + (current['end_y'] - current['start_y']) * progress
            self.target.move_to(new_x, new_y)
            
        elif current['type'] == 'rotate':
            new_angle = current['start_angle'] + (current['end_angle'] - current['start_angle']) * progress
            self.target.rotate(new_angle)
            
        elif current['type'] == 'scale':
            new_scale = current['start_scale'] + (current['end_scale'] - current['start_scale']) * progress
            self.target.scale_to(new_scale)
            
        if progress >= 1.0:
            self.actions.pop(0)  # Удаляем завершенную анимацию
