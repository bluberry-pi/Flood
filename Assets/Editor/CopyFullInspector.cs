using UnityEngine;
using UnityEditor;
using System.Text;

public static class CopyFullInspector
{
    [MenuItem("GameObject/Copy Full Serialized Inspector", false, 0)]
    private static void CopyFullSerializedInspector()
    {
        GameObject go = Selection.activeGameObject;

        if (go == null)
            return;

        StringBuilder output = new StringBuilder();

        output.AppendLine("============================================================");
        output.AppendLine("GAMEOBJECT: " + go.name);
        output.AppendLine("============================================================");

        Component[] components = go.GetComponents<Component>();

        foreach (Component component in components)
        {
            output.AppendLine();
            output.AppendLine("============================================================");

            if (component == null)
            {
                output.AppendLine("COMPONENT: MISSING");
                output.AppendLine("============================================================");
                continue;
            }

            output.AppendLine(
                "COMPONENT: " + component.GetType().FullName
            );

            output.AppendLine("============================================================");

            DumpComponent(component, output);
        }

        GUIUtility.systemCopyBuffer = output.ToString();

        Debug.Log(
            "Copied complete serialized Inspector data for: " + go.name
        );
    }


    [MenuItem("GameObject/Copy Full Serialized Inspector", true)]
    private static bool ValidateCopy()
    {
        return Selection.activeGameObject != null;
    }


    private static void DumpComponent(
        Component component,
        StringBuilder output)
    {
        SerializedObject serializedObject =
            new SerializedObject(component);

        serializedObject.Update();

        SerializedProperty property =
            serializedObject.GetIterator();

        // Move to first property
        if (!property.Next(true))
            return;

        do
        {
            // Don't include the C# script reference
            if (property.propertyPath == "m_Script")
                continue;

            output.AppendLine(
                new string(' ', property.depth * 2) +
                property.displayName +
                " [" +
                property.propertyPath +
                "] = " +
                GetValue(property)
            );

        } while (property.Next(false));
    }


    private static string GetValue(
        SerializedProperty property)
    {
        switch (property.propertyType)
        {
            case SerializedPropertyType.Integer:
                return property.intValue.ToString();

            case SerializedPropertyType.Boolean:
                return property.boolValue.ToString();

            case SerializedPropertyType.Float:
                return property.floatValue.ToString("G");

            case SerializedPropertyType.String:
                return "\"" + property.stringValue + "\"";

            case SerializedPropertyType.Color:
                return
                    "RGBA(" +
                    property.colorValue.r.ToString("F4") + ", " +
                    property.colorValue.g.ToString("F4") + ", " +
                    property.colorValue.b.ToString("F4") + ", " +
                    property.colorValue.a.ToString("F4") +
                    ")";

            case SerializedPropertyType.Vector2:
                return property.vector2Value.ToString("F4");

            case SerializedPropertyType.Vector3:
                return property.vector3Value.ToString("F4");

            case SerializedPropertyType.Vector4:
                return property.vector4Value.ToString("F4");

            case SerializedPropertyType.Quaternion:
                return property.quaternionValue.ToString("F4");

            case SerializedPropertyType.Rect:
                return property.rectValue.ToString();

            case SerializedPropertyType.Bounds:
                return property.boundsValue.ToString();

            case SerializedPropertyType.LayerMask:
                return property.intValue.ToString();

            case SerializedPropertyType.Enum:
                return GetEnumValue(property);

            case SerializedPropertyType.ObjectReference:

                if (property.objectReferenceValue == null)
                    return "NULL";

                return
                    property.objectReferenceValue.name +
                    " (" +
                    property.objectReferenceValue.GetType().Name +
                    ")";

            case SerializedPropertyType.AnimationCurve:

                if (property.animationCurveValue == null)
                    return "NULL";

                return property.animationCurveValue.ToString();

            case SerializedPropertyType.ExposedReference:

                if (property.exposedReferenceValue == null)
                    return "NULL";

                return
                    property.exposedReferenceValue.name +
                    " (" +
                    property.exposedReferenceValue.GetType().Name +
                    ")";

            case SerializedPropertyType.ManagedReference:

                if (property.managedReferenceValue == null)
                    return "NULL";

                return property.managedReferenceValue.ToString();

            case SerializedPropertyType.Hash128:
                return property.hash128Value.ToString();

            case SerializedPropertyType.FixedBufferSize:
                return property.fixedBufferSize.ToString();

            case SerializedPropertyType.Generic:
                return "<Generic>";

            default:
                return "<" + property.propertyType + ">";
        }
    }


    private static string GetEnumValue(
        SerializedProperty property)
    {
        string[] names = property.enumDisplayNames;

        int index = property.enumValueIndex;

        if (
            names != null &&
            index >= 0 &&
            index < names.Length
        )
        {
            return names[index];
        }

        return "EnumIndex=" + index;
    }
}