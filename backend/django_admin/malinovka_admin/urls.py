from django.contrib import admin
from django.urls import path


admin.site.site_header = "Malinovka Smart Home"
admin.site.site_title = "Malinovka Admin"
admin.site.index_title = "Управление устройствами"

urlpatterns = [
    path("admin/", admin.site.urls),
]
