#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif
#include <gdk/gdkkeysyms.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// منع الإغلاق من مدير النوافذ
static gboolean on_delete_event(GtkWidget *widget, GdkEvent *event, gpointer user_data) {
  return TRUE; // لا تغلق النافذة
}

// إعادة fullscreen إذا خرج منها المستخدم
static gboolean on_window_state_event(GtkWidget *widget, GdkEventWindowState *event, gpointer user_data) {
  GtkWindow *window = GTK_WINDOW(widget);
  if (!(event->new_window_state & GDK_WINDOW_STATE_FULLSCREEN)) {
    gtk_window_fullscreen(window);
  }
  return FALSE;
}

// منع Alt+F4 و F11
static gboolean on_key_press(GtkWidget *widget, GdkEventKey *event, gpointer user_data) {
  if ((event->state & GDK_MOD1_MASK) && event->keyval == GDK_KEY_F4) {
    return TRUE; // منع Alt+F4
  }
  if (event->keyval == GDK_KEY_F11) {
    return TRUE; // منع F11
  }
  return FALSE; // السماح بباقي المفاتيح
}

// بعد أول إطار من Flutter
static void first_frame_cb(MyApplication* self, FlView *view) {
  GtkWidget* window = gtk_widget_get_toplevel(GTK_WIDGET(view));
  gtk_widget_show(window);
  gtk_window_fullscreen(GTK_WINDOW(window)); // إجبار fullscreen بعد ظهور الإطار
}

// -------------------------------------------
//              Main Activate
// -------------------------------------------
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  GtkWidget* window_widget = GTK_WIDGET(window);
  gtk_widget_set_app_paintable(window_widget, TRUE);

  // إزالة الديكور + منع التغيير بالحجم
  gtk_window_set_decorated(window, FALSE);
  gtk_window_set_resizable(window, FALSE);

  // تمكين الشفافية في النافذة
  GdkScreen* screen = gtk_window_get_screen(window);
  GdkVisual* visual = gdk_screen_get_rgba_visual(screen);
  if (visual != nullptr) {
    gtk_widget_set_visual(window_widget, visual);
  }

  // ربط الأحداث لمنع الإغلاق والخروج من fullscreen
  g_signal_connect(window_widget, "delete-event", G_CALLBACK(on_delete_event), NULL);
  g_signal_connect(window_widget, "window-state-event", G_CALLBACK(on_window_state_event), NULL);
  g_signal_connect(window_widget, "key-press-event", G_CALLBACK(on_key_press), NULL);

  // الحصول على حجم الشاشة الحديثة (بدون deprecated)
  GdkDisplay* display = gdk_display_get_default();
  GdkMonitor* monitor = gdk_display_get_primary_monitor(display);
  if (monitor == NULL) {
    // fallback إذا لم يوجد monitor رئيسي
    monitor = gdk_display_get_monitor(display, 0);
  }

  GdkRectangle geometry;
  gdk_monitor_get_geometry(monitor, &geometry);

  gtk_window_move(window, geometry.x, geometry.y);
  gtk_window_set_default_size(window, geometry.width, geometry.height);

  // خلفية Flutter
  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);

  // ✅ جعل الخلفية سوداء بنسبة شفافية 30%
  GdkRGBA background_color;
  background_color.red = 0.0;
  background_color.green = 0.0;
  background_color.blue = 0.0;
  background_color.alpha = 0.1; // <-- شفافية 30%
  fl_view_set_background_color(view, &background_color);

  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // عرض النافذة بعد أول إطار من Flutter
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb), self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));
  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// -------------------------------------------
//        باقي دوال التطبيق الافتراضية
// -------------------------------------------
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;
  return TRUE;
}

static void my_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

static void my_application_shutdown(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  g_set_prgname(APPLICATION_ID);
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
