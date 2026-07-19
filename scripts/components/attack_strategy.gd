extends RefCounted
class_name AttackStrategy


func fire(
        source_position: Vector2,
        target: SproutEnemy,
        tower_data: TowerData,
        damage: float,
        projectile_pool: ProjectilePool,
        enemy_registry: EnemyRegistry,
        status_effect_override: StatusEffectData = null,
        critical_hit: bool = false
) -> void:
    push_error("AttackStrategy.fire must be implemented by a concrete strategy.")