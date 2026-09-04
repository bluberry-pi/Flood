using UnityEngine;

public class BoatController : MonoBehaviour
{
    [Header("Movement")]
    public float moveSpeed = 5f;
    public float turnSpeed = 60f;

    [Header("Water Behaviour")]
    public float submergeDepth = 0.15f;   // how far the hull sits below its own pivot
    public float idleBobAmplitude = 0.05f;
    public float idleBobSpeed = 1.2f;

    private float baseY;
    private float bobTimer;

    void Start()
    {
        baseY = transform.position.y - submergeDepth;
    }

    void Update()
    {
        float move = Input.GetAxis("Vertical");   // W/S
        float turn = Input.GetAxis("Horizontal"); // A/D
        bool isMoving = Mathf.Abs(move) > 0.05f;

        transform.Translate(Vector3.up * move * moveSpeed * Time.deltaTime, Space.Self);
        transform.Rotate(Vector3.up, turn * turnSpeed * Time.deltaTime, Space.World);

        // idle bob calms down while underway, like a real hull
        bobTimer += Time.deltaTime * (isMoving ? 0.3f : 1f);
        float bobOffset = Mathf.Sin(bobTimer * idleBobSpeed) * idleBobAmplitude;
        Vector3 pos = transform.position;
        pos.y = baseY + bobOffset;
        transform.position = pos;
    }
}