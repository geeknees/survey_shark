module ApplicationHelper
  def current_admin
    Current.session&.admin
  end

  def navigation_link_class(path)
    base_classes = "text-gray-700 hover:text-blue-600 px-3 py-2 rounded-md text-sm font-medium"
    active_classes = "text-blue-600 bg-blue-50"

    is_active = current_page?(path) || (path == projects_path && current_page?(root_path))

    if is_active
      "#{base_classes} #{active_classes}"
    else
      base_classes
    end
  end

  def mobile_navigation_link_class(path)
    base_classes = "text-gray-700 hover:text-blue-600 block px-3 py-2 rounded-md text-base font-medium"
    active_classes = "text-blue-600 bg-blue-50"

    is_active = current_page?(path) || (path == projects_path && current_page?(root_path))

    if is_active
      "#{base_classes} #{active_classes}"
    else
      base_classes
    end
  end
end
