extends AttackStrategy
class_name ProjectileAttackStrategy


func fire(
        source_position: Vector2,
        target: SproutEnemy,
        tower_data: TowerData,
        damage: float,
        projectile_pool: ProjectilePool,
        enemy_registry: EnemyRegistry,
        status_effect_override: StatusEffectData = null
) -> void:
    if target == null or tower_data == null or projectile_pool == null:
        return
    projectile_pool.launch(
        source_position,
        target,
        damage,
        tower_data.projectile_speed,
        tower_data.projectile_color,
        tower_data.projectile_size,
        tower_data.splash_radius,
        status_effect_override if status_effect_override != null else tower_data.status_effect,
        enemy_registry
    )