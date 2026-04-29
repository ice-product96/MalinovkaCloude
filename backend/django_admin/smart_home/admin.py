from django.contrib import admin

from .models import (
    AppSetting,
    CookingProgram,
    Device,
    DeviceCommand,
    DeviceType,
    Room,
    TelemetryEvent,
    User,
    UserCookingProgram,
)


@admin.register(AppSetting)
class AppSettingAdmin(admin.ModelAdmin):
    list_display = ("id", "home_background_url", "updated_at")
    fields = ("id", "home_background_url", "created_at", "updated_at")
    readonly_fields = ("created_at", "updated_at")


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ("id", "name", "created_at")
    search_fields = ("name",)
    readonly_fields = ("created_at", "updated_at")


@admin.register(Room)
class RoomAdmin(admin.ModelAdmin):
    list_display = ("id", "name", "user", "created_at")
    search_fields = ("name",)
    list_filter = ("user",)
    readonly_fields = ("created_at", "updated_at")


class DeviceCommandInline(admin.TabularInline):
    model = DeviceCommand
    extra = 0
    fields = ("name", "transport", "template", "description", "schema")


@admin.register(DeviceType)
class DeviceTypeAdmin(admin.ModelAdmin):
    list_display = ("id", "display_name", "manufacturer", "is_active", "image_url")
    search_fields = ("id", "display_name", "manufacturer")
    list_filter = ("manufacturer", "is_active")
    inlines = (DeviceCommandInline,)
    readonly_fields = ("created_at", "updated_at")


@admin.register(DeviceCommand)
class DeviceCommandAdmin(admin.ModelAdmin):
    list_display = ("id", "device_type", "name", "transport", "template")
    search_fields = ("name", "template", "description")
    list_filter = ("device_type", "transport")
    readonly_fields = ("created_at", "updated_at")


@admin.register(CookingProgram)
class CookingProgramAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "name",
        "device_type",
        "mode",
        "volume_group",
        "dish_category",
        "duration_minutes",
        "temperature_celsius",
        "mode_code",
    )
    search_fields = ("name", "dish_category")
    list_filter = ("device_type", "mode", "volume_group", "dish_category")
    readonly_fields = ("created_at", "updated_at")


@admin.register(UserCookingProgram)
class UserCookingProgramAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "name",
        "user",
        "device_type",
        "mode",
        "duration_minutes",
        "temperature_celsius",
    )
    search_fields = ("name",)
    list_filter = ("user", "device_type", "mode")
    readonly_fields = ("created_at", "updated_at")


@admin.register(Device)
class DeviceAdmin(admin.ModelAdmin):
    list_display = ("id", "name", "external_id", "room", "device_type", "connection_mode", "updated_at")
    search_fields = ("name", "external_id")
    list_filter = ("room", "device_type", "connection_mode")
    readonly_fields = ("created_at", "updated_at")


@admin.register(TelemetryEvent)
class TelemetryEventAdmin(admin.ModelAdmin):
    list_display = ("id", "device", "created_at")
    search_fields = ("device__name", "device__external_id")
    list_filter = ("device",)
    readonly_fields = ("created_at", "updated_at")
