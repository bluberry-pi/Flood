using UnityEngine;
using Unity.Cinemachine;

public class CameraOrbit : MonoBehaviour
{
    [Header("Target")]
    public Transform target;

    [Header("Camera Orbit")]
    public float mouseSensitivity = 3f;
    public float cameraDistance = 14f;
    public float cameraHeight = 10f;

    [Header("Starting Angle")]
    public float startingAngle = 0f;

    private CinemachineFollow follow;
    private float currentAngle;

    void Start()
    {
        follow = GetComponent<CinemachineFollow>();

        if (follow == null)
        {
            Debug.LogError("CameraOrbit requires a Cinemachine Follow component.");
            enabled = false;
            return;
        }

        currentAngle = startingAngle;
    }

    void LateUpdate()
    {
        if (target == null)
            return;

        // Only read horizontal mouse movement
        float mouseX = Input.GetAxis("Mouse X");

        // Rotate around the player
        currentAngle += mouseX * mouseSensitivity;

        float radians = currentAngle * Mathf.Deg2Rad;

        // Calculate horizontal orbit position
        float x = Mathf.Sin(radians) * cameraDistance;
        float z = -Mathf.Cos(radians) * cameraDistance;

        // Tell Cinemachine where to position the camera
        follow.FollowOffset = new Vector3(
            x,
            cameraHeight,
            z
        );

        // Make the camera look at the player.
        Vector3 cameraPosition = target.position + follow.FollowOffset;

        transform.rotation = Quaternion.LookRotation(
            target.position - cameraPosition,
            Vector3.up
        );
    }
}