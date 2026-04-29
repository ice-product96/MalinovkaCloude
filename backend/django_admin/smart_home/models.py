from django.db import models


class TimestampMixin(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


class User(TimestampMixin):
    id = models.IntegerField(primary_key=True)
    name = models.CharField(max_length=120)

    class Meta:
        managed = False
        db_table = "users"
        verbose_name = "Пользователь"
        verbose_name_plural = "Пользователи"

    def __str__(self) -> str:
        return self.name


class Room(TimestampMixin):
    id = models.IntegerField(primary_key=True)
    name = models.CharField(max_length=120)
    user = models.ForeignKey(User, models.DO_NOTHING, db_column="user_id", default=1)

    class Meta:
        managed = False
        db_table = "rooms"
        verbose_name = "Помещение"
        verbose_name_plural = "Помещения"

    def __str__(self) -> str:
        return self.name


class DeviceType(TimestampMixin):
    id = models.CharField(max_length=80, primary_key=True)
    display_name = models.CharField(max_length=160)
    manufacturer = models.CharField(max_length=120)
    description = models.TextField(blank=True)
    image_url = models.CharField(max_length=255)
    ble_profile = models.JSONField(default=dict)
    capabilities = models.JSONField(default=dict)
    is_active = models.BooleanField(default=True)

    class Meta:
        managed = False
        db_table = "device_types"
        verbose_name = "Тип устройства"
        verbose_name_plural = "Типы устройств"

    def __str__(self) -> str:
        return self.display_name


class DeviceCommand(TimestampMixin):
    id = models.IntegerField(primary_key=True)
    device_type = models.ForeignKey(DeviceType, models.DO_NOTHING, db_column="device_type_id")
    name = models.CharField(max_length=80)
    transport = models.CharField(max_length=40)
    template = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    schema = models.JSONField(default=dict)

    class Meta:
        managed = False
        db_table = "device_commands"
        verbose_name = "Команда устройства"
        verbose_name_plural = "Команды устройств"

    def __str__(self) -> str:
        return f"{self.device_type_id}: {self.name}"


class CookingProgram(TimestampMixin):
    id = models.IntegerField(primary_key=True)
    device_type = models.ForeignKey(DeviceType, models.DO_NOTHING, db_column="device_type_id")
    name = models.CharField(max_length=160)
    mode = models.CharField(max_length=80)
    volume_group = models.CharField(max_length=80)
    dish_category = models.CharField(max_length=120)
    duration_minutes = models.IntegerField()
    temperature_celsius = models.IntegerField()
    mode_code = models.IntegerField()

    class Meta:
        managed = False
        db_table = "cooking_programs"
        verbose_name = "Программа приготовления"
        verbose_name_plural = "Программы приготовления"

    def __str__(self) -> str:
        return self.name


class UserCookingProgram(TimestampMixin):
    id = models.IntegerField(primary_key=True)
    user = models.ForeignKey(User, models.DO_NOTHING, db_column="user_id", default=1)
    device_type = models.ForeignKey(DeviceType, models.DO_NOTHING, db_column="device_type_id")
    name = models.CharField(max_length=160)
    mode = models.CharField(max_length=80)
    volume_group = models.CharField(max_length=80)
    dish_category = models.CharField(max_length=120)
    duration_minutes = models.IntegerField()
    temperature_celsius = models.IntegerField()
    mode_code = models.IntegerField()

    class Meta:
        managed = False
        db_table = "user_cooking_programs"
        verbose_name = "Пользовательская программа"
        verbose_name_plural = "Пользовательские программы"

    def __str__(self) -> str:
        return self.name


class Device(TimestampMixin):
    id = models.IntegerField(primary_key=True)
    room = models.ForeignKey(Room, models.DO_NOTHING, db_column="room_id")
    device_type = models.ForeignKey(DeviceType, models.DO_NOTHING, db_column="device_type_id")
    external_id = models.CharField(max_length=120, unique=True)
    name = models.CharField(max_length=160)
    connection_mode = models.CharField(max_length=40)
    last_state = models.JSONField(default=dict, blank=True)

    class Meta:
        managed = False
        db_table = "devices"
        verbose_name = "Устройство"
        verbose_name_plural = "Устройства"

    def __str__(self) -> str:
        return self.name


class TelemetryEvent(TimestampMixin):
    id = models.IntegerField(primary_key=True)
    device = models.ForeignKey(Device, models.DO_NOTHING, db_column="device_id")
    payload = models.JSONField(default=dict)

    class Meta:
        managed = False
        db_table = "telemetry_events"
        verbose_name = "Событие телеметрии"
        verbose_name_plural = "События телеметрии"

    def __str__(self) -> str:
        return f"{self.device_id}: {self.created_at}"


class AppSetting(TimestampMixin):
    id = models.IntegerField(primary_key=True, default=1)
    home_background_url = models.CharField(max_length=255)

    class Meta:
        managed = False
        db_table = "app_settings"
        verbose_name = "Настройка приложения"
        verbose_name_plural = "Настройки приложения"

    def __str__(self) -> str:
        return "Настройки приложения"
