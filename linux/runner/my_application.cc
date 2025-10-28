#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include "flutter/generated_plugin_registrant.h"

// 1. إضافة المكتبات اللازمة لـ X11
#ifdef GDK_WINDOWING_X11
// يجب تغليف مكتبات C بـ extern "C" عند استخدام C++
extern "C" {
  #include <gdk/gdkx.h>
  #include <X11/Xlib.h>
  #include <X11/Xatom.h> // لإدارة الـ Atoms
}
#endif

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView *view)
{
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  GtkWidget* window_widget = GTK_WIDGET(window);
  gtk_widget_set_app_paintable(window_widget, TRUE);
  GdkScreen* screen = gtk_window_get_screen(window);
#if GTK_CHECK_VERSION(3, 0, 0)
  GdkVisual* visual = gdk_screen_get_rgba_visual(screen);
  if (visual != nullptr) {
    gtk_widget_set_visual(window_widget, visual);
  }
#endif

  // Get display and monitor information using modern GDK API
  GdkDisplay* display = gtk_widget_get_display(window_widget);
  GdkMonitor* primary_monitor = gdk_display_get_primary_monitor(display);
  GdkRectangle monitor_geometry;
  gdk_monitor_get_geometry(primary_monitor, &monitor_geometry);

  // Set window dimensions with scaling factor
  GdkMonitor* monitor = gdk_display_get_primary_monitor(display);
  double scale_factor = gdk_monitor_get_scale_factor(monitor);
  int window_height = 50 * scale_factor;  // Account for HiDPI scaling
  int window_width = monitor_geometry.width;
  gtk_window_set_default_size(window, window_width, window_height);
  
  // Force the window size
  gtk_widget_set_size_request(window_widget, window_width, window_height);

  // Set window properties
  gtk_window_set_keep_above(window, TRUE);
  gtk_window_set_decorated(window, FALSE);
  gtk_window_stick(window);

  // "تحقيق" النافذة (Realize)
  // يجب أن نفعل هذا الآن لنحصل على معرّف X11 (XID)
  gtk_widget_realize(window_widget);

  // Position the window 20 pixels above the bottom of the screen
  gtk_window_move(window, 0, monitor_geometry.height - window_height - 20);


#ifdef GDK_WINDOWING_X11
  GdkWindow* gdk_window = gtk_widget_get_window(window_widget);
  if (GDK_IS_X11_WINDOW(gdk_window)) {
    Display* xdisplay = GDK_DISPLAY_XDISPLAY(display);
    Window xid = GDK_WINDOW_XID(gdk_window);

    // Set window type to DOCK
    ::Atom type_atom = ::XInternAtom(xdisplay, "_NET_WM_WINDOW_TYPE", False);
    ::Atom dock_atom = ::XInternAtom(xdisplay, "_NET_WM_WINDOW_TYPE_DOCK", False);
    ::XChangeProperty(xdisplay, xid, type_atom, XA_ATOM, 32, PropModeReplace,
                    reinterpret_cast<unsigned char*>(&dock_atom), 1);

    // Reserve space at bottom of screen
    ::Atom strut_atom = ::XInternAtom(xdisplay, "_NET_WM_STRUT_PARTIAL", False);
    // Ensure struts use the scaled height plus 20px gap
    long strut[12] = {0, 0, 0, static_cast<long>(window_height + 20),
                      0, 0, 0, 0,
                      0, static_cast<long>(window_width), 0, 0};
    ::XChangeProperty(xdisplay, xid, strut_atom, XA_CARDINAL, 32, PropModeReplace,
                    reinterpret_cast<unsigned char*>(strut), 12);

    ::XFlush(xdisplay);
  }
#endif
  // --- نهاية التعديلات

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000 for transparent.
    gdk_rgba_parse(&background_color, "#00000000"); // transparent
    fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb), self);
  // gtk_widget_realize(GTK_WIDGET(view)); // <-- تم نقله للأعلى

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
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

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
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
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}